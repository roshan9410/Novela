id = "readnovel_entrepreneur"
name = "ReadNovel - Entrepreneur Tycoon"
version = "1.0.2"
baseUrl = "https://www.readnovel.com"
language = "zh"
charset = "UTF-8"
icon = "https://www.google.com/s2/favicons?sz=128&domain=readnovel.com"

local bookUrl = baseUrl .. "/bookquery/zfiqclmiurjd"
local bookTitle = "让你创业亏钱，结果你成首富了？"

local function absUrl(href)
    if not href or href == "" then return "" end
    if string.sub(href, 1, 2) == "//" then return "https:" .. href end
    if string.sub(href, 1, 7) == "http://" or string.sub(href, 1, 8) == "https://" then
        return href
    end
    return url_resolve(baseUrl, href)
end

local function fetchBookPage(url)
    local r = http_get(url, { charset = "UTF-8" })
    if not r.success then return nil end
    return r.body
end

function getCatalogList(index)
    if index > 0 then return { items = {}, hasNext = false } end
    return {
        items = {
            { title = bookTitle, url = bookUrl, cover = nil }
        },
        hasNext = false
    }
end

function getCatalogSearch(index, query)
    if index > 0 then return { items = {}, hasNext = false } end

    local q = string.lower(query or "")
    local titleLower = string.lower(bookTitle)
    if q == "" or string.find(titleLower, q, 1, true)
        or string.find(q, "创业", 1, true)
        or string.find(q, "亏钱", 1, true)
        or string.find(q, "首富", 1, true)
        or string.find(q, "王列", 1, true) then
        return {
            items = {
                { title = bookTitle, url = bookUrl, cover = nil }
            },
            hasNext = false
        }
    end
    return { items = {}, hasNext = false }
end

function getBookTitle(url)
    local html = fetchBookPage(url)
    if not html then return bookTitle end
    local el = html_select_first(html, "h1 > em")
    if el then return string_clean(el.text) end
    el = html_select_first(html, "h1")
    return el and string_clean(el.text) or bookTitle
end

function getBookCoverImageUrl(url)
    local html = fetchBookPage(url)
    if not html then return nil end
    local cover = html_attr(html, "meta[property='og:image']", "content")
    if cover and cover ~= "" then return absUrl(cover) end
    cover = html_attr(html, "img", "src")
    return cover ~= "" and absUrl(cover) or nil
end

function getBookDescription(url)
    local html = fetchBookPage(url)
    if not html then return nil end
    local desc = html_attr(html, "meta[property='og:description']", "content")
    if desc and desc ~= "" then return string_trim(desc) end
    return nil
end

function getBookStatus(url)
    local html = fetchBookPage(url)
    if not html then return nil end
    local status = html_attr(html, "meta[property='og:novel:status']", "content")
    if status and status ~= "" then return status end
    local text = string_clean(html)
    if string.find(text, "完结", 1, true) then return "完结" end
    if string.find(text, "连载", 1, true) then return "连载" end
    return nil
end

-- ReadNovel has changed its catalog markup across desktop/mobile versions.
-- Prefer known catalog containers, then fall back to all chapter-looking links.
function getChapterList(url)
    local html = fetchBookPage(url)
    if not html then return {} end

    local chapters = {}
    local seen = {}

    local selectors = {
        ".volume > ul > li > a",
        ".volume a",
        ".catalog a",
        ".chapter-list a",
        ".book-list a",
        ".directory a",
        "ul li a"
    }

    local function addLink(a)
        local href = a.href
        local title = string_clean(a.text)
        if not href or href == "" or title == "" then return end
        if not string.match(title, "第%s*[%d一二三四五六七八九十百千万]+%s*章")
            and not string.match(title, "Chapter%s+%d+") then
            return
        end
        local u = absUrl(href)
        if u == "" or seen[u] then return end
        seen[u] = true
        table.insert(chapters, { title = title, url = u })
    end

    for _, selector in ipairs(selectors) do
        for _, a in ipairs(html_select(html, selector)) do
            addLink(a)
        end
        if #chapters >= 1 then break end
    end

    -- Last-resort scan of every anchor. This handles markup changes where the
    -- chapter list no longer lives under .volume/.catalog.
    if #chapters == 0 then
        for _, a in ipairs(html_select(html, "a")) do
            addLink(a)
        end
    end

    return chapters
end

function getChapterText(html, url)
    -- Try the common ReadNovel reader containers first, then several
    -- alternative layouts used by desktop/mobile mirrors.
    local selectors = {
        ".read-content",
        ".chapter-content",
        ".txtnav",
        "#content",
        ".content",
        "article",
        "main",
        ".read",
        ".chapter",
        ".txt"
    }

    local content = nil
    for _, selector in ipairs(selectors) do
        content = html_select_first(html, selector)
        if content then break end
    end

    if not content then
        -- Avoid returning the whole navigation page unless there is genuinely
        -- no better reader container.
        return nil
    end

    local inner = content.html or ""
    local cleaned = html_remove(inner,
        "script,style,nav,header,footer,.read-chapter-download,.download-bar,.ad,.ads,.advertisement,.visible-xs"
    )

    local text = html_text(cleaned)
    text = string_normalize(text)
    text = string_trim(text)

    -- Remove common chapter-heading / site-noise prefixes without touching
    -- the story body.
    text = regex_replace(text, "(?i)^\\s*(第[0-9一二三四五六七八九十百千万]+章[^\\n\\r]*[\\n\\r]+)+", "")
    text = string_trim(text)

    if text == "" then return nil end
    return text
end

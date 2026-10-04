id = "readnovel_entrepreneur"
name = "ReadNovel - Entrepreneur Tycoon"
version = "1.0.0"
baseUrl = "https://www.readnovel.com"
language = "zh"
charset = "UTF-8"

local bookUrl = baseUrl .. "/bookquery/zfiqclmiurrh"
local bookTitle = "让你创业亏钱，结果你成首富了？"

local function absUrl(href)
    if not href or href == "" then return "" end
    if string.sub(href, 1, 2) == "//" then return "https:" .. href end
    if string.sub(href, 1, 7) == "http://" or string.sub(href, 1, 8) == "https://" then
        return href
    end
    if string.sub(href, 1, 1) == "/" then return baseUrl .. href end
    return baseUrl .. "/" .. href
end

local function fetchBookPage(url)
    local r = http_get(url)
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
    local text = string_clean(html)
    if string.find(text, "完结", 1, true) then return "完结" end
    if string.find(text, "连载", 1, true) then return "连载" end
    return nil
end

function getChapterList(url)
    local html = fetchBookPage(url)
    if not html then return {} end

    local chapters = {}
    for _, a in ipairs(html_select(html, ".volume > ul > li > a")) do
        local href = a.href
        local title = string_clean(a.text)
        if href and href ~= "" and title ~= "" then
            table.insert(chapters, { title = title, url = absUrl(href) })
        end
    end

    return chapters
end

function getChapterText(html, url)
    local content = html_select_first(html, ".read-content")
    if not content then
        content = html_select_first(html, ".chapter-content")
    end
    if not content then return nil end

    local cleaned = html_remove(content.html,
        "script,style,.read-chapter-download,.download-bar,.ad,.ads,.advertisement"
    )
    local el = html_select_first(cleaned, ".read-content")
    if not el then el = html_select_first(cleaned, ".chapter-content") end
    if not el then return html_text(cleaned) end
    return html_text(el.html)
end

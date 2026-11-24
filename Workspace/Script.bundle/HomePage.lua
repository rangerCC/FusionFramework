-- M0 占位首页，M1 替换为三个 Tab 页面
local page = Page.new("HomePage", "PCHomePage", "home")
page.hide_navi = true
page.singleton = true
register_page(page)

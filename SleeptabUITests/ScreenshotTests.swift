import XCTest

/// Chinese screenshots for Sleeptab via `-seedDemo` sleep data and `-paywall`.
final class ScreenshotTests: XCTestCase {

    private func save(_ shot: XCUIScreenshot, _ name: String) {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? shot.pngRepresentation.write(to: dir.appendingPathComponent(name))
        let a = XCTAttachment(screenshot: shot); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    @MainActor
    func testCaptureScreenshots() {
        let app = XCUIApplication()
        // -pro: 30/90 晚区间是 Pro 功能，截图需要解锁态
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_Hans", "-seedDemo", "-pro"]
        app.launch()
        XCTAssertTrue(app.staticTexts["洞察 · 最近 7 晚"].waitForExistence(timeout: 15))
        save(XCUIScreen.main.screenshot(), "sleeptab-zh-1-top.png")
        // 切到 30 晚区间，等洞察标题更新后再截，避免截到未变化的画面
        app.buttons["30 晚"].tap()
        XCTAssertTrue(app.staticTexts["洞察 · 最近 30 晚"].waitForExistence(timeout: 10))
        save(XCUIScreen.main.screenshot(), "sleeptab-zh-2-week.png")
        app.terminate()

        let app2 = XCUIApplication()
        // -isPro NO: 覆盖上面 -pro 落盘的解锁缓存，否则 paywall 会自动关闭
        app2.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_Hans", "-paywall", "-isPro", "NO"]
        app2.launch()
        sleep(3)
        save(XCUIScreen.main.screenshot(), "sleeptab-zh-3-paywall.png")
    }
}

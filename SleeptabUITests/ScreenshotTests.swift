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
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_Hans", "-seedDemo"]
        app.launch()
        sleep(6)
        save(XCUIScreen.main.screenshot(), "sleeptab-zh-1-top.png")
        app.swipeUp(); sleep(2)
        save(XCUIScreen.main.screenshot(), "sleeptab-zh-2-week.png")
        app.terminate()

        let app2 = XCUIApplication()
        app2.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_Hans", "-paywall"]
        app2.launch()
        sleep(3)
        save(XCUIScreen.main.screenshot(), "sleeptab-zh-3-paywall.png")
    }
}

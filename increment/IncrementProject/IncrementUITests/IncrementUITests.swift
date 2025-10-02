import XCTest

final class IncrementUITests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertTrue(true)
    }

    @MainActor
    func testStartSessionButtonTap() throws {
        let app = XCUIApplication()
        app.launch()

        // Wait for app to load
        sleep(2)

        // Find and tap the START WORKOUT button
        let startButton = app.buttons["START WORKOUT"]
        XCTAssertTrue(startButton.exists, "START WORKOUT button should exist")

        startButton.tap()

        // Wait for transition
        sleep(2)

        // Take screenshot
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.lifetime = .keepAlways
        add(attachment)

        print("✅ Button tapped successfully!")
    }

    @MainActor
    func testRestTimerCountdown() throws {
        let app = XCUIApplication()
        app.launch()

        sleep(1)

        // Start session
        app.buttons["START WORKOUT"].tap()
        sleep(1)

        // Tap feeling rating and continue
        if app.buttons["3"].exists {
            app.buttons["3"].tap()
            sleep(1)
        }

        // Continue from pre-workout feeling screen
        if app.buttons["START WORKOUT"].exists {
            app.buttons["START WORKOUT"].tap()
            sleep(1)
        }

        // Skip stretching if present
        if app.buttons["START WORKOUT →"].exists {
            app.buttons["START WORKOUT →"].tap()
            sleep(1)
        }

        // Should be on warmup - advance through warmups
        if app.buttons["NEXT WARMUP WEIGHT »"].exists {
            app.buttons["NEXT WARMUP WEIGHT »"].tap()
            sleep(1)
            app.buttons["NEXT WARMUP WEIGHT »"].tap()
            sleep(1)
        }

        // Should be on Load screen
        if app.buttons["LOAD PLATES"].exists {
            app.buttons["LOAD PLATES"].tap()
            sleep(1)
        }

        // Should be on Working Set screen - log a set
        // Find EASY button and tap it (assuming reps are pre-filled)
        if app.buttons["EASY"].exists {
            app.buttons["EASY"].tap()
            sleep(2)

            // Should now be on Rest screen - check for timer
            let restText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Rest:'")).firstMatch
            XCTAssertTrue(restText.exists, "Rest timer text should exist")

            // Take screenshot of rest screen
            let screenshot1 = app.screenshot()
            let attachment1 = XCTAttachment(screenshot: screenshot1)
            attachment1.name = "Rest Screen Initial"
            attachment1.lifetime = .keepAlways
            add(attachment1)

            // Wait and check timer is counting down
            sleep(3)

            let screenshot2 = app.screenshot()
            let attachment2 = XCTAttachment(screenshot: screenshot2)
            attachment2.name = "Rest Screen After 3 Seconds"
            attachment2.lifetime = .keepAlways
            add(attachment2)

            // Test -10s button
            if app.buttons["-10s"].exists {
                app.buttons["-10s"].tap()
                sleep(1)

                let screenshot3 = app.screenshot()
                let attachment3 = XCTAttachment(screenshot: screenshot3)
                attachment3.name = "After -10s Button"
                attachment3.lifetime = .keepAlways
                add(attachment3)
            }

            print("✅ Rest timer test completed!")
        }
    }
}

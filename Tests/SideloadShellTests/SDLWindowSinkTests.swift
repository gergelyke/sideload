import CSDL2
import Foundation
import Testing
import SideloadRender
@testable import SideloadShell

@Suite struct SDLWindowSinkTests {
    @Test @MainActor func opensPresentsAndClosesOnQuitEvent() throws {
        guard ProcessInfo.processInfo.environment["DISPLAY"] != nil else {
            return // No X server available; skip rather than fail.
        }

        let sink = SDLWindowSink(title: "Sideload Test", pointWidth: 100, pointHeight: 100, pixelWidth: 100, pixelHeight: 100, scale: 1)

        let quitThread = Thread {
            Thread.sleep(forTimeInterval: 0.3)
            var event = SDL_Event()
            event.type = SDL_QUIT.rawValue
            SDL_PushEvent(&event)
        }
        quitThread.start()

        var produceCount = 0
        try sink.run { pixelWidth, pixelHeight, scale in
            produceCount += 1
            return Frame(pixelWidth: pixelWidth, pixelHeight: pixelHeight, scale: scale)
        }
        #expect(produceCount >= 1)
    }
}

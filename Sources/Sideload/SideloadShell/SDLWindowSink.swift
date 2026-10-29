import CSDL2
import SideloadRender

public enum SDLWindowError: Error, Sendable {
    case initFailed(String)
}

/// Shows a window at 1 OS pixel per point, internally rendering frames at
/// the device's native pixel resolution and letting SDL scale the texture
/// down (or up) to the window's size. Exits its run loop on `SDL_QUIT` —
/// which SDL's own default signal handlers raise for SIGINT/SIGTERM, so
/// this sink never installs its own signal handling.
@MainActor
public final class SDLWindowSink: FrameSink {
    private let title: String
    private let pointWidth: Int
    private let pointHeight: Int
    private let pixelWidth: Int
    private let pixelHeight: Int
    private let scale: Double

    public init(title: String, pointWidth: Int, pointHeight: Int, pixelWidth: Int, pixelHeight: Int, scale: Double) {
        self.title = title
        self.pointWidth = pointWidth
        self.pointHeight = pointHeight
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.scale = scale
    }

    public func run(_ produce: (Int, Int, Double) -> Frame) throws {
        if SDL_Init(UInt32(SDL_INIT_VIDEO)) != 0 {
            throw SDLWindowError.initFailed(String(cString: SDL_GetError()))
        }
        defer { SDL_Quit() }

        guard let window = SDL_CreateWindow(
            title,
            Int32(SDL_WINDOWPOS_UNDEFINED_MASK), Int32(SDL_WINDOWPOS_UNDEFINED_MASK),
            Int32(pointWidth), Int32(pointHeight),
            SDL_WINDOW_SHOWN.rawValue
        ) else {
            throw SDLWindowError.initFailed(String(cString: SDL_GetError()))
        }
        defer { SDL_DestroyWindow(window) }

        guard let renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED.rawValue) else {
            throw SDLWindowError.initFailed(String(cString: SDL_GetError()))
        }
        defer { SDL_DestroyRenderer(renderer) }

        guard let texture = SDL_CreateTexture(
            renderer,
            SDL_PIXELFORMAT_ARGB8888.rawValue,
            Int32(SDL_TEXTUREACCESS_STREAMING.rawValue),
            Int32(pixelWidth), Int32(pixelHeight)
        ) else {
            throw SDLWindowError.initFailed(String(cString: SDL_GetError()))
        }
        defer { SDL_DestroyTexture(texture) }

        func redraw() {
            var frame = produce(pixelWidth, pixelHeight, scale)
            frame.buffer.withUnsafeMutableBufferPointer { ptr in
                _ = SDL_UpdateTexture(texture, nil, ptr.baseAddress, Int32(frame.stride))
            }
            SDL_RenderClear(renderer)
            SDL_RenderCopy(renderer, texture, nil, nil)
            SDL_RenderPresent(renderer)
        }

        redraw()

        var event = SDL_Event()
        eventLoop: while true {
            guard SDL_WaitEvent(&event) != 0 else { break }
            switch SDL_EventType(rawValue: event.type) {
            case SDL_QUIT:
                break eventLoop
            case SDL_WINDOWEVENT:
                if SDL_WindowEventID(rawValue: UInt32(event.window.event)) == SDL_WINDOWEVENT_EXPOSED {
                    redraw()
                }
            default:
                break
            }
        }
    }
}

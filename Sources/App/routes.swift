import Vapor

func routes(_ app: Application) throws {
    let liveViewHandler = LiveViewHandler()
    app.get(use: liveViewHandler.handle)
    app.webSocket("ws", onUpgrade: liveViewHandler.handleWebSocket)
}

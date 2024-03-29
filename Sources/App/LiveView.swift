//
//  LiveView.swift
//  
//
//  Created by Ahmad Alhashemi on 25/03/2024.
//

import Vapor
import Observation

// DivConvertible.swift
@resultBuilder
struct DivBuilder {
    static func buildBlock(_ components: DivConvertible...) -> [DivConvertible] {
        return components
    }
}

protocol DivConvertible {
    var _id: UUID { get }
    func render() -> String
    func handle(action: UUID)
}

struct RawHTML: DivConvertible {
    let _id: UUID = UUID()
    let content: String
    
    init(_ content: String) {
        self.content = content
    }
    
    func render() -> String {
        return content
    }
    
    func handle(action: UUID) { }
}

struct Div: DivConvertible {
    let _id: UUID = UUID()
    let body: [DivConvertible]
    
    init(@DivBuilder _ content: () -> [DivConvertible]) {
        body = content()
    }
    
    func render() -> String {
        let innerContent = body.map { $0.render() }.joined()
        return "<div id=\"\(_id)\">\(innerContent)</div>"
    }
    
    func handle(action: UUID) {
        print("handling \(action) in Div")
        body.forEach { $0.handle(action: action) }
    }
}

struct Button: DivConvertible {
    let _id: UUID
    let label: String
    let action: () -> ()
    
    init(id: UUID, label: String, action: @escaping () -> ()) {
        self._id = id
        self.label = label
        self.action = action
    }
    
    func render() -> String {
        return "<button id=\"\(_id)\" onclick=\"handleButtonClick('\(_id)')\">\(label)</button>"
    }
    
    func handle(action: UUID) {
        print("handling \(action) in Button with id \(self._id)")
        if action == self._id {
            self.action()
        }
    }
}

struct CustomView: DivConvertible {
    let context = LiveViewContext()
    let _id = UUID()
    let incId: UUID
    let decId: UUID

    var body: Div {
        Div {
            RawHTML("<h1>Count: \(context.count)</h1>")
            Button(id: incId, label: "Increment") {
                context.count += 1
            }
            Button(id: decId, label: "Decrement") {
                context.count -= 1
            }
        }
    }

    func render() -> String {
        return body.render()
    }

    func handle(action: UUID) {
        print("handling \(action) in CustomView")
        self.body.handle(action: action)
    }
}

@Observable final class LiveViewContext {
    var count: Int = 0
    init(count: Int = 0) {
        self.count = count
    }
}

class LiveViewHandler {
    func handle(_ req: Request) -> EventLoopFuture<Response> {
        let script = """
        <script>
            var socket = new WebSocket("ws://localhost:8080/ws");

            function handleButtonClick(id) {
                socket.send(id);
            }

            socket.onmessage = function (event) {
                document.getElementById("live-view").innerHTML = event.data;
            };
        </script>
        """

        let html = """
        <html>
            <body>
                <div id="live-view"></div>
                \(script)
            </body>
        </html>
        """
        
        let response = Response(status: .ok, body: .init(string: html))
        response.headers.contentType = .html
        
        return req.eventLoop.makeSucceededFuture(response)
    }

    func handleWebSocket(_ req: Request, _ ws: WebSocket) {
        let view = CustomView(incId: UUID(), decId: UUID())
        
        @Sendable func renderView() {
            withObservationTracking {
                let html = view.render()
                ws.send(html)
            } onChange: {
                print("change detected")
                renderView()
            }
        }
        
        renderView()
        
        ws.onText { ws, text in
            if let id = UUID(uuidString: text) {
                view.handle(action: id)
            }
        }
    }
}

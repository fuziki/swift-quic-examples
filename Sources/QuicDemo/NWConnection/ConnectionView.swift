//
//  ConnectionView.swift
//  
//
//  Created by fuziki on 2023/05/02.
//

import Foundation
import Network
import SwiftUI

struct ConnectionView: View {
    @StateObject var vm = ConnectionViewModel()
    var body: some View {
        Section {
            Text("State: \(vm.state.flatMap({ "\($0)" }) ?? "No Connection")")
            if vm.state == nil {
                Button {
                    vm.connect()
                } label: {
                    Text("Connect")
                }
            } else {
                Button {
                    vm.disconnect()
                } label: {
                    Text("Disconnect")
                }
                Button {
                    vm.send()
                } label: {
                    Text("Send \"Hello\"")
                }
                VStack(alignment: .leading) {
                    Text("Receive Message:")
                    Text(vm.receive ?? "No Message")
                }
            }
        } header: {
            Text("CONNECTION EXAMPLE")
        }
    }
}

class ConnectionViewModel: ObservableObject {
    @Published var state: NWConnection.State? = nil
    @Published var receive: String?

    private var connection: NWConnection?
    private let queue = DispatchQueue.main

    func connect() {
        print("connect")
        let options = NWProtocolQUIC.Options(alpn: ["echo"])
        options.direction = .bidirectional
        let securityProtocolOptions: sec_protocol_options_t = options.securityProtocolOptions
        sec_protocol_options_set_verify_block(securityProtocolOptions,
                                              { (_: sec_protocol_metadata_t,
                                                 _: sec_trust_t,
                                                 complete: @escaping sec_protocol_verify_complete_t) in
            complete(true) // Insecure !!!
        }, DispatchQueue.main)
        let params = NWParameters(quic: options)
        connection = .init(to: ENDPOINT, using: params)
        state = connection?.state
        subscribe()

        connection?.stateUpdateHandler = { [weak self] (state: NWConnection.State) in
            self?.state = state
            if state == .cancelled {
                self?.connection = nil
                self?.state = nil
                self?.receive = nil
            }
        }

        connection?.start(queue: queue)
    }

    func disconnect() {
        connection?.cancel()
    }

    func send() {
        let completion: NWConnection.SendCompletion = .contentProcessed { (error: Error?) in
            print("send error: \(String(describing: error))")
        }
        connection?.send(content: "Hello".data(using: .utf8)!,
                         contentContext: .defaultMessage,
                         isComplete: false,
                         completion: completion)
    }

    private func subscribe() {
        connection?
            .receive(minimumIncompleteLength: 1,
                     maximumLength: 128) { [weak self] (content: Data?,
                                                        contentContext: NWConnection.ContentContext?,
                                                        isComplete: Bool,
                                                        error: NWError?) in
                self?.subscribe()
                let msg = content.flatMap { "\(String(data: $0, encoding: .utf8) ?? "\($0)") @\(Date())" }
                self?.receive = msg ?? "\(String(describing: content))"
                print("receive content: \(String(describing: content))")
                print("receive contentContext: \(String(describing: contentContext))")
                print("receive isComplete: \(isComplete)")
                print("receive error: \(String(describing: error))")
        }
    }
}

struct ConnectionView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            ConnectionView()
        }
    }
}

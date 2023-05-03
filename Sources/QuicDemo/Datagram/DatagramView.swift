//
//  DatagramView.swift
//  
//
//  Created by fuziki on 2023/05/03.
//

import Foundation
import Network
import SwiftUI

struct DatagramView: View {
    @StateObject var vm = DatagramViewModel()
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
            Text("DATAGRAM EXAMPLE")
        }
    }
}

class DatagramViewModel: ObservableObject {
    @Published var state: NWConnectionGroup.State? = nil
    @Published var receive: String?

    private var group: NWConnectionGroup?
    private let queue = DispatchQueue.main

    func connect() {
        print("connect")
        let options = NWProtocolQUIC.Options(alpn: ["echo"])
        options.direction = .bidirectional
        options.isDatagram = true
        options.maxDatagramFrameSize = 1200
        let securityProtocolOptions: sec_protocol_options_t = options.securityProtocolOptions
        sec_protocol_options_set_verify_block(securityProtocolOptions,
                                              { (_: sec_protocol_metadata_t,
                                                 _: sec_trust_t,
                                                 complete: @escaping sec_protocol_verify_complete_t) in
            complete(true) // Insecure !!!
        }, DispatchQueue.main)
        let params = NWParameters(quic: options)
        let desc = NWMultiplexGroup(to: ENDPOINT)
        group = NWConnectionGroup(with: desc, using: params)
        state = group?.state
        subscribe()

        group?.stateUpdateHandler = { [weak self] (state: NWConnectionGroup.State) in
            self?.state = state
            if state == .cancelled {
                self?.group = nil
                self?.state = nil
                self?.receive = nil
            }
        }

        group?.start(queue: queue)
    }

    func disconnect() {
        group?.cancel()
    }

    func send() {
        group?.send(content: "Hello".data(using: .utf8)!) { (error: Error?) in
            print("send error: \(String(describing: error))")
        }
    }

    private func subscribe() {
        group?
            .setReceiveHandler { [weak self] (message: NWConnectionGroup.Message,
                                              content: Data?,
                                              isComplete: Bool) in
                let msg = content.flatMap { "\(String(data: $0, encoding: .utf8) ?? "\($0)") @\(Date())" }
                self?.receive = msg ?? "\(String(describing: content))"
                print("receive message: \(message)")
                print("receive content: \(String(describing: content))")
                print("receive isComplete: \(isComplete)")
            }
    }
}

struct DatagramView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            DatagramView()
        }
    }
}

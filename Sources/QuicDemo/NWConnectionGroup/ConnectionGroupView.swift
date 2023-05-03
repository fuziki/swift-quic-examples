//
//  ConnectionGroupView.swift
//
//
//  Created by fuziki on 2023/05/03.
//
 
import Foundation
import Network
import SwiftUI

struct ConnectionGroupView: View {
    @StateObject var vm = ConnectionGroupViewModel()
    var body: some View {
        Section {
            Text("Group State: \(vm.groupState.flatMap({ "\($0)" }) ?? "No Group")")
            Text("Open Connection State: \(vm.openConnectionState.flatMap({ "\($0)" }) ?? "No Connection")")
            Text("Accept Connection State: \(vm.acceptConnectionState.flatMap({ "\($0)" }) ?? "No Connection")")
            group
            connection
        } header: {
            Text("[WIP] CONNECTION GROUP EXAMPLE")
        }
    }

    @ViewBuilder
    var group: some View {
        if vm.groupState == nil {
            Button {
                vm.createGroup()
            } label: {
                Text("Create Group")
            }
        } else {
            Button {
                vm.cancelGroup()
            } label: {
                Text("Cancel Group")
            }
        }
    }

    @ViewBuilder
    var connection: some View {
        if vm.openConnectionState == nil {
            Button {
                vm.createConnection()
            } label: {
                Text("Create Connection")
            }
        } else {
            Button {
                vm.cancelConnection()
            } label: {
                Text("Cancel Open Connection")
            }
            Button {
                vm.sendToOpenConnection()
            } label: {
                Text("Send \"Hello\" to Open Connection")
            }
            VStack(alignment: .leading) {
                Text("Receive Message from Open Connection:")
                Text(vm.receiveFromOpenConnection ?? "No Message")
            }
        }
        if vm.acceptConnectionState != nil {
            Button {
                vm.sendToAcceptConnection()
            } label: {
                Text("Send \"Hello\" to Accept Connection")
            }
            VStack(alignment: .leading) {
                Text("Receive Message from Accept Connection:")
                Text(vm.receiveFromAcceptConnection ?? "No Message")
            }
        }
    }
}

class ConnectionGroupViewModel: ObservableObject {
    @Published var groupState: NWConnectionGroup.State?
    @Published var openConnectionState: NWConnection.State?
    @Published var acceptConnectionState: NWConnection.State?
    @Published var receiveFromOpenConnection: String?
    @Published var receiveFromAcceptConnection: String?

    private var group: NWConnectionGroup?
    private var openConnection: NWConnection?
    private var acceptConnection: NWConnection?

    private let queue = DispatchQueue.main

    func createGroup() {
        print("Create Group")
        let options = NWProtocolQUIC.Options(alpn: ["echo"])
        options.direction = .bidirectional
        options.isDatagram = true
        options.maxDatagramFrameSize = 65535
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
        groupState = group?.state

        group?.stateUpdateHandler = { [weak self] (state: NWConnectionGroup.State) in
            self?.groupState = state
        }

        group?.newConnectionHandler = { [weak self] (connection: NWConnection) in
            print("new connection: \(connection)")
            self?.acceptConnection = connection
            self?.acceptConnection?.stateUpdateHandler = { [weak self] (state: NWConnection.State) in
                self?.acceptConnectionState = state
            }
            self?.subscribeAcceptConnection()
            self?.acceptConnection?.start(queue: self!.queue)
        }

        group?.start(queue: queue)
    }

    func cancelGroup() {
        group?.cancel()
    }

    func createConnection() {
        guard let group else { return }

        let options = NWProtocolQUIC.Options(alpn: ["echo"])
        options.direction = .bidirectional
        options.isDatagram = false
        let securityProtocolOptions: sec_protocol_options_t = options.securityProtocolOptions
        sec_protocol_options_set_verify_block(securityProtocolOptions,
                                              { (_: sec_protocol_metadata_t,
                                                 _: sec_trust_t,
                                                 complete: @escaping sec_protocol_verify_complete_t) in
            complete(true) // Insecure !!!
        }, DispatchQueue.main)

        // Error: POSIXErrorCode(rawValue: 50): Network is down
        // nw_endpoint_flow_setup_cloned_protocols [C3 xxx.xxx.xxx.xxx:4433 in_progress socket-flow (satisfied (Path is satisfied), viable, interface: lo0)] could not find protocol to join in existing protocol stack
        // nw_endpoint_flow_failed_with_error [C3 xxx.xxx.xxx.xxx:4433 in_progress socket-flow (satisfied (Path is satisfied), viable, interface: lo0)] failed to clone from flow, moving directly to failed state
        // openConnection = .init(from: group, using: options)

        // OK
        openConnection = .init(from: group)

        // OK
        // openConnection = group.extract()

        openConnectionState = openConnection?.state
        subscribeOpenConnection()

        openConnection?.stateUpdateHandler = { [weak self] (state: NWConnection.State) in
            self?.openConnectionState = state
        }

        openConnection?.start(queue: queue)
    }

    func cancelConnection() {
        openConnection?.cancel()
    }

    func sendToOpenConnection() {
        let completion: NWConnection.SendCompletion = .contentProcessed { (error: Error?) in
            print("send error: \(String(describing: error))")
        }
        // Error: POSIXErrorCode(rawValue: 45): Operation not supported
        // nw_flow_copy_write_request [C3 xxx.xxx.xxx.xxx:4433 ready socket-flow (satisfied (Path is satisfied), viable, interface: lo0)] Protocol does not support sending incomplete send content
        // nw_write_request_report [C3] Send failed with error "Operation not supported"
        // nw_flow_prepare_output_frames [C3 xxx.xxx.xxx.xxx:4433 ready socket-flow (satisfied (Path is satisfied), viable, interface: lo0)] Failed to use 1 frames, marking as failed
        openConnection?.send(content: "Hello".data(using: .utf8)!,
                             contentContext: .defaultMessage,
                             isComplete: false,
                             completion: completion)
    }

    func sendToAcceptConnection() {
        let completion: NWConnection.SendCompletion = .contentProcessed { (error: Error?) in
            print("send error: \(String(describing: error))")
        }
        acceptConnection?.send(content: "Hello".data(using: .utf8)!,
                               contentContext: .defaultMessage,
                               isComplete: false,
                               completion: completion)
    }

    private func subscribeOpenConnection() {
        openConnection?
            .receive(minimumIncompleteLength: 1,
                     maximumLength: 128) { [weak self] (content: Data?,
                                                        contentContext: NWConnection.ContentContext?,
                                                        isComplete: Bool,
                                                        error: NWError?) in
                self?.subscribeOpenConnection()
                let msg = content.flatMap { "\(String(data: $0, encoding: .utf8) ?? "\($0)") @\(Date())" }
                self?.receiveFromOpenConnection = msg ?? "\(String(describing: content))"
                print("Open Connection Receive content: \(String(describing: content))")
                print("Open Connection Receive contentContext: \(String(describing: contentContext))")
                print("Open Connection Receive isComplete: \(isComplete)")
                print("Open Connection Receive error: \(String(describing: error))")
        }
    }

    private func subscribeAcceptConnection() {
        acceptConnection?
            .receive(minimumIncompleteLength: 1,
                     maximumLength: 128) { [weak self] (content: Data?,
                                                        contentContext: NWConnection.ContentContext?,
                                                        isComplete: Bool,
                                                        error: NWError?) in
                self?.subscribeAcceptConnection()
                let msg = content.flatMap { "\(String(data: $0, encoding: .utf8) ?? "\($0)") @\(Date())" }
                self?.receiveFromAcceptConnection = msg ?? "\(String(describing: content))"
                print("Accept Connection Receive content: \(String(describing: content))")
                print("Accept Connection Receive contentContext: \(String(describing: contentContext))")
                print("Accept Connection Receive isComplete: \(isComplete)")
                print("Accept Connection Receive error: \(String(describing: error))")
        }
    }
}

struct ConnectionGroupView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            ConnectionGroupView()
        }
    }
}

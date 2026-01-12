//
//  ContentView.swift
//  PairMe
//
//  Created by Oleksii Kolomiiets on 1/10/26.
//

import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @Environment(\.peripheralManager) var peripheralManager
    @State private var isAdvertising: Bool = false
    @State private var isEditing: Bool = false
    @State private var showAddServiceSheet: Bool = false

    var body: some View {
        VStack {
            VStack(spacing: 16) {
                HStack(spacing: 32)  {
                    Text("**Advertise**")
                    Spacer()
                        .frame(maxWidth: .infinity)
                    Toggle("", isOn: $isAdvertising)
                }
                if let error = peripheralManager.error {
                    Text("Error: \(error.localizedDescription)")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding([.top, .horizontal], 16)

            AddedServicesList(isAdvertising: $isAdvertising, isEditing: isEditing)
        }
        .multilineTextAlignment(.leading)
        .navigationTitle("My Services")
        .navigationBarTitleDisplayMode(.automatic)
        .onDisappear {
            isAdvertising = false
        }
        .onChange(of: isAdvertising, initial: true) {
            if isAdvertising {
                peripheralManager.startAdvertising()
            } else {
                peripheralManager.stopAdvertising()
            }
        }
        .toolbar {
            Button {
                showAddServiceSheet = true
            } label: {
                Text("Add")
            }

            Button {
                isEditing.toggle()
            } label: {
                Text(isEditing ? "Done" : "Edit")
            }

        }
        .sheet(isPresented: $showAddServiceSheet) {
            AddServiceView()
        }
    }
}

#Preview {
    NavigationStack {
        ContentView()
    }
}

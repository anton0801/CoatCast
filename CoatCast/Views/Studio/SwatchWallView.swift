//
//  SwatchWallView.swift
//  CoatCast
//
//  Feature 06 (Swatch Wall): the palette of every room's color. Tap a swatch to
//  rebind a color to that room; saved mixes can be applied with one tap.
//

import SwiftUI

struct SwatchWallView: View {
    @EnvironmentObject var store: AppStore
    @State private var editingRoomID: UUID?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScreenScaffold("Swatch Wall", subtitle: "Bind a color to each room") {
            VStack(spacing: Theme.Space.m) {
                if store.rooms.isEmpty {
                    EmptyStateCard(icon: "square.grid.2x2", title: "No rooms",
                                   message: "Add rooms in the Studio tab to start your color wall.")
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(store.rooms) { room in
                            Button(action: { editingRoomID = room.id }) {
                                swatchCell(room)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                if !store.mixes.isEmpty {
                    SectionHeader(title: "Saved mixes", systemImage: "eyedropper.halffull")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(store.mixes) { mix in
                                VStack(spacing: 6) {
                                    Circle().fill(Color(hex: mix.resultHex)).frame(width: 46, height: 46)
                                        .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))
                                    Text(mix.name).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                                        .lineLimit(1).frame(width: 60)
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: Binding(get: { editingRoomID.map { IDWrap(id: $0) } },
                             set: { editingRoomID = $0?.id })) { wrap in
            SwatchEditorSheet(roomID: wrap.id).environmentObject(store)
        }
    }

    private func swatchCell(_ room: PaintRoom) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color(hex: room.colorHex)).frame(height: 90)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(room.name).font(Theme.heading(14)).foregroundColor(Theme.textPrimary).lineLimit(1)
                    Text(String(format: "#%06X", room.colorHex)).font(Theme.caption(11))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "paintbrush.fill").foregroundColor(Theme.accent)
            }
            .padding(12)
            .background(Theme.surface)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.stroke, lineWidth: 1))
        .shadow(color: Theme.shadow, radius: 6, y: 3)
    }
}

private struct IDWrap: Identifiable { let id: UUID }

private struct SwatchEditorSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    let roomID: UUID
    @State private var hex: UInt = 0xFFFFFF

    var body: some View {
        NavigationView {
            ScreenScaffold(store.room(roomID)?.name ?? "Room", subtitle: "Pick a swatch color") {
                VStack(spacing: Theme.Space.m) {
                    CardView {
                        VStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Color(hex: hex))
                                .frame(height: 110)
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.stroke, lineWidth: 1))
                            SwatchPicker(hex: $hex)
                        }
                    }
                    if !store.mixes.isEmpty {
                        CardView {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeader(title: "Apply a mix", systemImage: "eyedropper.halffull")
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(store.mixes) { mix in
                                            Button(action: { hex = mix.resultHex }) {
                                                Circle().fill(Color(hex: mix.resultHex)).frame(width: 44, height: 44)
                                                    .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                            }
                        }
                    }
                    ActionButton(title: "Save Color", systemImage: "checkmark.circle.fill") {
                        if var room = store.room(roomID) { room.colorHex = hex; store.updateRoom(room) }
                        presentationMode.wrappedValue.dismiss()
                    }
                    ActionButton(title: "Cancel", kind: .secondary) { presentationMode.wrappedValue.dismiss() }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear { hex = store.room(roomID)?.colorHex ?? 0xFFFFFF }
    }
}

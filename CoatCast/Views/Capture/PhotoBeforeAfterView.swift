//
//  PhotoBeforeAfterView.swift
//  CoatCast
//
//  Feature 11 (Photo Before/After): capture a before and an after photo per
//  room with a caption. Two independent pickers writing two filename slots.
//

import SwiftUI

struct PhotoBeforeAfterView: View {
    @EnvironmentObject var store: AppStore
    @State private var showEditor = false
    @State private var editing: PhotoPair?

    var body: some View {
        ScreenScaffold("Before / After", subtitle: "Document the transformation") {
            VStack(spacing: Theme.Space.m) {
                ActionButton(title: "New Photo Set", systemImage: "plus.circle.fill") {
                    editing = nil; showEditor = true
                }
                if store.photoPairs.isEmpty {
                    EmptyStateCard(icon: "photo.on.rectangle.angled", title: "No photos yet",
                                   message: "Capture a before shot, paint, then capture the after.")
                } else {
                    ForEach(store.photoPairs) { pair in
                        Button(action: { editing = pair; showEditor = true }) { pairCard(pair) }
                            .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            PhotoPairEditor(existing: editing).environmentObject(store)
        }
    }

    private func pairCard(_ pair: PhotoPair) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if let r = store.room(pair.roomID) {
                        Text(r.name).font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                    } else {
                        Text("Photo set").font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                    }
                    Spacer()
                    Text(Formatters.date(pair.createdAt)).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                }
                HStack(spacing: 10) {
                    thumb(pair.beforeFileName, "Before")
                    thumb(pair.afterFileName, "After")
                }
                if !pair.caption.isEmpty {
                    Text(pair.caption).font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                }
            }
        }
    }

    private func thumb(_ name: String?, _ label: String) -> some View {
        VStack(spacing: 4) {
            ZStack {
                if let img = PhotoStore.shared.loadImage(named: name) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Theme.surfaceAlt.overlay(Image(systemName: "photo").foregroundColor(Theme.textInactive))
                }
            }
            .frame(height: 96).frame(maxWidth: .infinity).clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(label).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
        }
    }
}

// MARK: - Editor

struct PhotoPairEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    let existing: PhotoPair?

    @State private var draft: PhotoPair
    @State private var camTarget: Target? = nil
    @State private var libTarget: Target? = nil
    private enum Target: Identifiable { case before, after; var id: Int { self == .before ? 0 : 1 } }

    init(existing: PhotoPair?) {
        self.existing = existing
        _draft = State(initialValue: existing ?? PhotoPair())
    }

    var body: some View {
        NavigationView {
            ScreenScaffold(existing == nil ? "New Photo Set" : "Edit Photo Set") {
                VStack(spacing: Theme.Space.m) {
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Room", systemImage: "square.split.bottomrightquarter")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    Chip(title: "None", isSelected: draft.roomID == nil) { draft.roomID = nil }
                                    ForEach(store.rooms) { r in
                                        Chip(title: r.name, isSelected: draft.roomID == r.id) { draft.roomID = r.id }
                                    }
                                }
                            }
                        }
                    }

                    PhotoSlot(fileName: draft.beforeFileName, label: "Before",
                              onCamera: { camTarget = .before }, onLibrary: { libTarget = .before },
                              onClear: { clear(.before) })
                    PhotoSlot(fileName: draft.afterFileName, label: "After",
                              onCamera: { camTarget = .after }, onLibrary: { libTarget = .after },
                              onClear: { clear(.after) })

                    LabeledTextField(label: "Caption", text: $draft.caption, placeholder: "Optional note")

                    ActionButton(title: existing == nil ? "Save Set" : "Save Changes",
                                 systemImage: "checkmark.circle.fill") {
                        store.addPhotoPair(draft); presentationMode.wrappedValue.dismiss()
                    }
                    if existing != nil {
                        ActionButton(title: "Delete Set", systemImage: "trash", kind: .danger) {
                            if let p = existing { store.deletePhotoPair(p) }
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    ActionButton(title: "Cancel", kind: .secondary) { presentationMode.wrappedValue.dismiss() }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(item: $camTarget) { target in
            CameraPicker { img in if let name = PhotoStore.shared.save(img) { set(target, name) } }
        }
        .sheet(item: $libTarget) { target in
            PhotoLibraryPicker { img in if let name = PhotoStore.shared.save(img) { set(target, name) } }
        }
    }

    private func set(_ target: Target, _ name: String) {
        switch target {
        case .before: PhotoStore.shared.delete(named: draft.beforeFileName); draft.beforeFileName = name
        case .after:  PhotoStore.shared.delete(named: draft.afterFileName);  draft.afterFileName = name
        }
    }
    private func clear(_ target: Target) {
        switch target {
        case .before: PhotoStore.shared.delete(named: draft.beforeFileName); draft.beforeFileName = nil
        case .after:  PhotoStore.shared.delete(named: draft.afterFileName);  draft.afterFileName = nil
        }
    }
}

//
//  DefectNoteView.swift
//  CoatCast
//
//  Capture tab home + Feature 10 (Defect Note): log drips / missed spots /
//  bubbles with a photo and a fix action, then mark them fixed.
//

import SwiftUI

// MARK: - Capture tab home

struct CaptureHomeView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScreenScaffold("Capture", subtitle: "Defects, photos & reports") {
            VStack(spacing: Theme.Space.m) {
                HStack(spacing: 12) {
                    StatTile(value: "\(store.openDefectCount)", label: "Open defects",
                             systemImage: "exclamationmark.triangle.fill", tint: Theme.defect)
                    StatTile(value: "\(store.photoPairs.count)", label: "Photo sets",
                             systemImage: "photo.on.rectangle.angled", tint: Theme.accent)
                }
                NavRow(icon: "exclamationmark.bubble.fill", title: "Defect Notes",
                       subtitle: "Drips, misses & bubbles", tint: Theme.defect) { DefectNoteView() }
                NavRow(icon: "photo.on.rectangle.angled", title: "Photo Before / After",
                       subtitle: "Document each room", tint: Theme.accent) { PhotoBeforeAfterView() }
                NavRow(icon: "doc.text.fill", title: "Reports",
                       subtitle: "Liters, cost & PDF export", tint: Theme.ready) { ReportsView() }
            }
        }
    }
}

// MARK: - Defect notes

struct DefectNoteView: View {
    @EnvironmentObject var store: AppStore
    @State private var showEditor = false
    @State private var editing: DefectNote?

    var body: some View {
        ScreenScaffold("Defect Notes", subtitle: "Fix the flaws") {
            VStack(spacing: Theme.Space.m) {
                ActionButton(title: "New Defect", systemImage: "plus.circle.fill") {
                    editing = nil; showEditor = true
                }
                if store.defects.isEmpty {
                    EmptyStateCard(icon: "checkmark.seal", title: "No defects logged",
                                   message: "Snap a photo of any drip or missed spot and note the fix.")
                } else {
                    ForEach(store.defects) { defect in
                        Button(action: { editing = defect; showEditor = true }) { defectCard(defect) }
                            .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            DefectEditorSheet(existing: editing).environmentObject(store)
        }
    }

    private func defectCard(_ d: DefectNote) -> some View {
        CardView(tint: d.isFixed ? Theme.ready : Theme.defect) {
            HStack(spacing: 12) {
                if let img = PhotoStore.shared.loadImage(named: d.imageFileName) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill((d.isFixed ? Theme.ready : Theme.defect).opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: d.kind.icon).foregroundColor(d.isFixed ? Theme.ready : Theme.defect)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(d.kind.displayName).font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                    if !d.fixAction.isEmpty {
                        Text(d.fixAction).font(Theme.caption(12)).foregroundColor(Theme.textSecondary).lineLimit(2)
                    }
                    if let r = store.room(d.roomID) { TagChip(text: r.name, color: Theme.accent) }
                }
                Spacer()
                TagChip(text: d.isFixed ? "Fixed" : "Open",
                        color: d.isFixed ? Theme.ready : Theme.defect, filled: true)
            }
        }
    }
}

// MARK: - Defect editor

struct DefectEditorSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    let existing: DefectNote?

    @State private var draft: DefectNote
    @State private var showCamera = false
    @State private var showLibrary = false

    init(existing: DefectNote?) {
        self.existing = existing
        _draft = State(initialValue: existing ?? DefectNote())
    }

    var body: some View {
        NavigationView {
            ScreenScaffold(existing == nil ? "New Defect" : "Edit Defect") {
                VStack(spacing: Theme.Space.m) {
                    PhotoSlot(fileName: draft.imageFileName,
                              onCamera: { showCamera = true },
                              onLibrary: { showLibrary = true },
                              onClear: { clearPhoto() })

                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Type", systemImage: "exclamationmark.triangle.fill")
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(DefectKind.allCases) { k in
                                    Chip(title: k.displayName, icon: k.icon, isSelected: draft.kind == k,
                                         tint: Theme.defect) { draft.kind = k }
                                }
                            }
                            SectionHeader(title: "Room", systemImage: "square.split.bottomrightquarter")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    Chip(title: "None", isSelected: draft.roomID == nil) { draft.roomID = nil }
                                    ForEach(store.rooms) { r in
                                        Chip(title: r.name, isSelected: draft.roomID == r.id) { draft.roomID = r.id }
                                    }
                                }
                            }
                            LabeledTextField(label: "How to fix", text: $draft.fixAction,
                                             placeholder: "e.g. Sand, recoat thin")
                        }
                    }

                    ActionButton(title: existing == nil ? "Save Defect" : "Save Changes",
                                 systemImage: "checkmark.circle.fill") {
                        store.addDefect(draft); presentationMode.wrappedValue.dismiss()
                    }
                    if existing != nil && !draft.isFixed {
                        ActionButton(title: "Mark Fixed", systemImage: "wrench.and.screwdriver.fill", kind: .secondary) {
                            store.markDefectFixed(draft); presentationMode.wrappedValue.dismiss()
                        }
                    }
                    if existing != nil {
                        ActionButton(title: "Delete", systemImage: "trash", kind: .danger) {
                            if let d = existing { store.deleteDefect(d) }
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    ActionButton(title: "Cancel", kind: .secondary) { presentationMode.wrappedValue.dismiss() }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showCamera) {
            CameraPicker { img in if let name = PhotoStore.shared.save(img) { setPhoto(name) } }
        }
        .sheet(isPresented: $showLibrary) {
            PhotoLibraryPicker { img in if let name = PhotoStore.shared.save(img) { setPhoto(name) } }
        }
    }

    private func setPhoto(_ name: String) {
        PhotoStore.shared.delete(named: draft.imageFileName)
        draft.imageFileName = name
    }
    private func clearPhoto() {
        PhotoStore.shared.delete(named: draft.imageFileName)
        draft.imageFileName = nil
    }
}

// MARK: - Reusable photo slot

struct PhotoSlot: View {
    let fileName: String?
    var label: String = "Photo"
    let onCamera: () -> Void
    let onLibrary: () -> Void
    let onClear: () -> Void

    var body: some View {
        CardView {
            VStack(spacing: 12) {
                ZStack {
                    if let img = PhotoStore.shared.loadImage(named: fileName) {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(height: 180).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.s))
                    } else {
                        RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt)
                            .frame(height: 180)
                            .overlay(VStack(spacing: 6) {
                                Image(systemName: "camera.fill").font(.system(size: 28)).foregroundColor(Theme.accent)
                                Text(label).font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                            })
                    }
                }
                HStack(spacing: 10) {
                    pickerButton("Camera", "camera.fill", onCamera)
                    pickerButton("Library", "photo.fill", onLibrary)
                    if fileName != nil {
                        Button(action: onClear) {
                            Image(systemName: "trash").foregroundColor(Theme.defect)
                                .frame(width: 44, height: 44)
                                .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    private func pickerButton(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) { Image(systemName: icon); Text(title) }
                .font(Theme.caption(13)).foregroundColor(Theme.onSecondary)
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.accent.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

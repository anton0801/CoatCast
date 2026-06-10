//
//  CostEstimateView.swift
//  CoatCast
//
//  Feature 08 (Cost Estimate): editable cost lines for paint, primer and
//  consumables with category + grand totals, plus a one-tap "estimate from plan"
//  that prefills paint/primer lines from the coverage engine.
//

import SwiftUI

struct CostEstimateView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing: CostItem?
    @State private var showEditor = false
    @State private var showEstimate = false
    @AppStorage("currencySymbol") private var currencySymbol = "$"

    var body: some View {
        ScreenScaffold("Cost Estimate", subtitle: "Materials for your plan") {
            VStack(spacing: Theme.Space.m) {
                // Totals
                CardView(tint: Theme.ready) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Total").font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                            Spacer()
                            Text(Formatters.currency(store.totalCost, symbol: currencySymbol))
                                .font(Theme.title(24)).foregroundColor(Theme.ready)
                        }
                        Divider().background(Theme.stroke)
                        ForEach(CostCategory.allCases) { cat in
                            HStack {
                                Image(systemName: cat.icon).foregroundColor(Theme.accent).font(.system(size: 13))
                                Text(cat.displayName).font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text(Formatters.currency(store.cost(in: cat), symbol: currencySymbol))
                                    .font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    ActionButton(title: "Add Item", systemImage: "plus.circle.fill") {
                        editing = nil; showEditor = true
                    }
                    ActionButton(title: "From Plan", systemImage: "wand.and.stars", kind: .secondary) {
                        showEstimate = true
                    }
                }

                if store.costItems.isEmpty {
                    EmptyStateCard(icon: "dollarsign.circle", title: "No costs yet",
                                   message: "Add items or estimate them straight from a room's plan.")
                } else {
                    ForEach(store.costItems) { item in
                        Button(action: { editing = item; showEditor = true }) { costRow(item) }
                            .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            CostEditorSheet(existing: editing).environmentObject(store)
        }
        .sheet(isPresented: $showEstimate) {
            EstimateFromPlanSheet().environmentObject(store)
        }
    }

    private func costRow(_ item: CostItem) -> some View {
        CardView {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.14)).frame(width: 38, height: 38)
                    Image(systemName: item.category.icon).foregroundColor(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(Theme.heading(15)).foregroundColor(Theme.textPrimary).lineLimit(1)
                    Text("\(Formatters.decimal(item.quantity)) × \(Formatters.currency(item.unitCost, symbol: currencySymbol))")
                        .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Text(Formatters.currency(item.total, symbol: currencySymbol))
                    .font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
            }
        }
    }
}

// MARK: - Cost editor

struct CostEditorSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    let existing: CostItem?
    @State private var draft: CostItem
    @AppStorage("currencySymbol") private var currencySymbol = "$"

    init(existing: CostItem?) {
        self.existing = existing
        _draft = State(initialValue: existing ?? CostItem(title: ""))
    }

    var body: some View {
        NavigationView {
            ScreenScaffold(existing == nil ? "Add Item" : "Edit Item") {
                VStack(spacing: Theme.Space.m) {
                    CardView {
                        VStack(spacing: 14) {
                            LabeledTextField(label: "Title", text: $draft.title, placeholder: "e.g. Masking tape")
                            SectionHeader(title: "Category", systemImage: "tag.fill")
                            HStack(spacing: 8) {
                                ForEach(CostCategory.allCases) { c in
                                    Chip(title: c.displayName, icon: c.icon, isSelected: draft.category == c) {
                                        draft.category = c
                                    }
                                }
                            }
                            LabeledNumberField(label: "Quantity", value: $draft.quantity)
                            LabeledNumberField(label: "Unit cost", value: $draft.unitCost, suffix: currencySymbol)
                        }
                    }
                    CardView(tint: Theme.ready) {
                        HStack {
                            Text("Line total").font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(Formatters.currency(draft.total, symbol: currencySymbol))
                                .font(Theme.heading(16)).foregroundColor(Theme.ready)
                        }
                    }
                    ActionButton(title: existing == nil ? "Add Item" : "Save Changes",
                                 systemImage: "checkmark.circle.fill",
                                 enabled: !draft.title.trimmingCharacters(in: .whitespaces).isEmpty) {
                        store.addCost(draft)
                        presentationMode.wrappedValue.dismiss()
                    }
                    if existing != nil {
                        ActionButton(title: "Delete Item", systemImage: "trash", kind: .danger) {
                            if let c = existing { store.deleteCost(c) }
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    ActionButton(title: "Cancel", kind: .secondary) { presentationMode.wrappedValue.dismiss() }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Estimate from plan

struct EstimateFromPlanSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    @State private var roomID: UUID?
    @State private var paintUnit: Double = 28
    @State private var primerUnit: Double = 18
    @AppStorage("currencySymbol") private var currencySymbol = "$"

    var body: some View {
        NavigationView {
            ScreenScaffold("Estimate From Plan", subtitle: "Prefill paint & primer cost") {
                VStack(spacing: Theme.Space.m) {
                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Room", systemImage: "square.split.bottomrightquarter")
                            if store.rooms.isEmpty {
                                Text("Add a room first.").font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(store.rooms) { r in
                                            Chip(title: r.name, isSelected: roomID == r.id) { roomID = r.id }
                                        }
                                    }
                                }
                            }
                            LabeledNumberField(label: "Paint cost per can", value: $paintUnit, suffix: currencySymbol)
                            LabeledNumberField(label: "Primer cost per can", value: $primerUnit, suffix: currencySymbol)
                        }
                    }
                    if let rid = roomID, let cov = store.coverage(for: rid) {
                        CardView(tint: Theme.accent) {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Paint: \(cov.paintCans) cans").font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Text(Formatters.currency(Double(cov.paintCans) * paintUnit, symbol: currencySymbol))
                                        .font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                                }
                                HStack {
                                    Text("Primer: \(cov.primerCans) cans").font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Text(Formatters.currency(Double(cov.primerCans) * primerUnit, symbol: currencySymbol))
                                        .font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                                }
                            }
                        }
                    }
                    ActionButton(title: "Add To Estimate", systemImage: "plus.circle.fill",
                                 enabled: roomID != nil) {
                        if let rid = roomID {
                            store.estimateCosts(for: rid, paintUnitCost: paintUnit, primerUnitCost: primerUnit)
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                    ActionButton(title: "Cancel", kind: .secondary) { presentationMode.wrappedValue.dismiss() }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear { if roomID == nil { roomID = store.rooms.first?.id } }
    }
}

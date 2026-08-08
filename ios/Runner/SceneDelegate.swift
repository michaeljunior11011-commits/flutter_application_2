import AVFoundation
import Charts
import Combine
import CoreMotion
import Foundation
import Flutter
import SwiftUI
import UIKit
import Vision

// MARK: - Persistent application data

private enum DashboardCard: String, Codable, CaseIterable, Identifiable {
  case weight
  case water
  case steps
  case empty
  case meals
  case weightTrend
  case sleep

  var id: String { rawValue }

  var title: String {
    switch self {
    case .weight: return "Weight"
    case .water: return "Water"
    case .steps: return "Steps"
    case .empty: return "Empty space"
    case .meals: return "Meals"
    case .weightTrend: return "Weight trend"
    case .sleep: return "Sleep"
    }
  }
}

private struct FoodEntry: Codable, Identifiable, Hashable {
  var id = UUID()
  var name: String
  var brand: String = ""
  var calories: Int
  var protein: Double
  var fat: Double
  var carbs: Double
  var meal: String = "Snack"
  var barcode: String?
}

private struct WeeklyValue: Identifiable {
  let id = UUID()
  let day: String
  let value: Double
}

private struct MensuraSnapshot: Codable {
  var caloriesConsumed: Int
  var caloriesRemaining: Int
  var calorieTarget: Int
  var protein: Double
  var proteinTarget: Double
  var fat: Double
  var fatTarget: Double
  var carbs: Double
  var carbsTarget: Double
  var waterMl: Int
  var waterGoalMl: Int
  var quickWaterMl: Int
  var weightKg: Double
  var weightGoalKg: Double
  var steps: Int
  var stepsGoal: Int
  var dashboardCards: [DashboardCard]
  var foodEntries: [FoodEntry]
  var waterReminders: Bool
  var calorieReminders: Bool
  var metricUnits: Bool
}

@MainActor
private final class MensuraStore: ObservableObject {
  @Published var caloriesConsumed = 100
  @Published var caloriesRemaining = 2600
  @Published var calorieTarget = 2900
  @Published var protein = 54.0
  @Published var proteinTarget = 120.0
  @Published var fat = 31.0
  @Published var fatTarget = 60.0
  @Published var carbs = 76.0
  @Published var carbsTarget = 350.0
  @Published var waterMl = 1000
  @Published var waterGoalMl = 2500
  @Published var quickWaterMl = 330
  @Published var weightKg = 60.0
  @Published var weightGoalKg = 75.0
  @Published var steps = 0
  @Published var stepsGoal = 10_000
  @Published var dashboardCards: [DashboardCard] = [.weight, .water, .steps]
  @Published var foodEntries: [FoodEntry] = []
  @Published var waterReminders = true
  @Published var calorieReminders = false
  @Published var metricUnits = true

  private let storageKey = "mensura.native.snapshot.v2"
  private let defaults = UserDefaults.standard
  private let pedometer = CMPedometer()

  init() {
    guard
      let data = defaults.data(forKey: storageKey),
      let snapshot = try? JSONDecoder().decode(MensuraSnapshot.self, from: data)
    else { return }

    caloriesConsumed = snapshot.caloriesConsumed
    caloriesRemaining = snapshot.caloriesRemaining
    calorieTarget = snapshot.calorieTarget
    protein = snapshot.protein
    proteinTarget = snapshot.proteinTarget
    fat = snapshot.fat
    fatTarget = snapshot.fatTarget
    carbs = snapshot.carbs
    carbsTarget = snapshot.carbsTarget
    waterMl = snapshot.waterMl
    waterGoalMl = snapshot.waterGoalMl
    quickWaterMl = snapshot.quickWaterMl
    weightKg = snapshot.weightKg
    weightGoalKg = snapshot.weightGoalKg
    steps = snapshot.steps
    stepsGoal = snapshot.stepsGoal
    // Older previews stored a synthetic empty card. Empty space is now created
    // by the adaptive grid, so it must never appear as a visible dashboard card.
    dashboardCards = snapshot.dashboardCards.filter { $0 != .empty }
    foodEntries = snapshot.foodEntries
    waterReminders = snapshot.waterReminders
    calorieReminders = snapshot.calorieReminders
    metricUnits = snapshot.metricUnits
  }

  func addWater(_ amount: Int, useAsShortcut: Bool = false) {
    guard amount > 0 else { return }
    waterMl = min(waterMl + amount, 10_000)
    if useAsShortcut { quickWaterMl = amount }
    save()
  }

  func setWaterGoal(_ amount: Int) {
    waterGoalMl = max(amount, 250)
    save()
  }

  func addFood(_ entry: FoodEntry) {
    foodEntries.insert(entry, at: 0)
    caloriesConsumed += entry.calories
    caloriesRemaining = max(caloriesRemaining - entry.calories, 0)
    protein += entry.protein
    fat += entry.fat
    carbs += entry.carbs
    save()
  }

  func addCalories(_ amount: Int, note: String) {
    addFood(
      FoodEntry(
        name: note.isEmpty ? "Quick calories" : note,
        calories: max(amount, 0),
        protein: 0,
        fat: 0,
        carbs: 0,
        meal: "Quick add"
      )
    )
  }

  func setWeight(_ value: Double) {
    weightKg = max(value, 1)
    save()
  }

  func setSteps(_ value: Int) {
    steps = max(value, 0)
    save()
  }

  func refreshStepsFromDevice() {
    guard CMPedometer.isStepCountingAvailable() else { return }
    let start = Calendar.current.startOfDay(for: Date())
    pedometer.queryPedometerData(from: start, to: Date()) { [weak self] data, _ in
      guard let measuredSteps = data?.numberOfSteps.intValue else { return }
      Task { @MainActor in
        self?.steps = measuredSteps
        self?.save()
      }
    }
  }

  func setWeightGoal(_ value: Double) {
    weightGoalKg = max(value, 1)
    save()
  }

  func moveCard(_ source: DashboardCard, before target: DashboardCard) {
    guard
      source != target,
      let sourceIndex = dashboardCards.firstIndex(of: source),
      let targetIndex = dashboardCards.firstIndex(of: target)
    else { return }

    var next = dashboardCards
    let card = next.remove(at: sourceIndex)
    let adjustedIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
    next.insert(card, at: max(0, adjustedIndex))
    dashboardCards = next
    save()
  }

  func hideCard(_ card: DashboardCard) {
    guard card != .empty else { return }
    dashboardCards.removeAll { $0 == card }
    save()
  }

  func showCard(_ card: DashboardCard) {
    guard card != .empty, !dashboardCards.contains(card) else { return }
    dashboardCards.append(card)
    save()
  }

  func setWaterReminders(_ enabled: Bool) {
    waterReminders = enabled
    save()
  }

  func setCalorieReminders(_ enabled: Bool) {
    calorieReminders = enabled
    save()
  }

  func setMetricUnits(_ enabled: Bool) {
    metricUnits = enabled
    save()
  }

  private func save() {
    let snapshot = MensuraSnapshot(
      caloriesConsumed: caloriesConsumed,
      caloriesRemaining: caloriesRemaining,
      calorieTarget: calorieTarget,
      protein: protein,
      proteinTarget: proteinTarget,
      fat: fat,
      fatTarget: fatTarget,
      carbs: carbs,
      carbsTarget: carbsTarget,
      waterMl: waterMl,
      waterGoalMl: waterGoalMl,
      quickWaterMl: quickWaterMl,
      weightKg: weightKg,
      weightGoalKg: weightGoalKg,
      steps: steps,
      stepsGoal: stepsGoal,
      dashboardCards: dashboardCards,
      foodEntries: foodEntries,
      waterReminders: waterReminders,
      calorieReminders: calorieReminders,
      metricUnits: metricUnits
    )
    guard let data = try? JSONEncoder().encode(snapshot) else { return }
    defaults.set(data, forKey: storageKey)
  }
}

// MARK: - Flutter to native transition

@MainActor
class SceneDelegate: FlutterSceneDelegate {
  private weak var flutterViewController: FlutterViewController?
  private var nativeShellController: UIViewController?
  private var nativeChannel: FlutterMethodChannel?
  private let store = MensuraStore()

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let flutterViewController = window?.rootViewController as? FlutterViewController else {
      return
    }

    self.flutterViewController = flutterViewController
    window?.backgroundColor = .systemBackground
    flutterViewController.view.backgroundColor = .systemBackground
    flutterViewController.overrideUserInterfaceStyle = .light

    let channel = FlutterMethodChannel(
      name: "com.mensura/native_shell",
      binaryMessenger: flutterViewController.binaryMessenger
    )
    nativeChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "showTabs":
        self.showNativeShell()
        result(nil)
      case "showWaterPicker":
        let arguments = call.arguments as? [String: Any]
        let amount = arguments?["current"] as? Int ?? self.store.quickWaterMl
        self.store.addWater(amount, useAsShortcut: true)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func showNativeShell() {
    guard nativeShellController == nil else { return }

    UIScrollView.appearance().bounces = false
    UIScrollView.appearance().alwaysBounceVertical = false

    if #available(iOS 26.0, *) {
      let controller = UIHostingController(rootView: MensuraNativeTabShell(store: store))
      controller.view.backgroundColor = .systemBackground
      controller.overrideUserInterfaceStyle = .light
      nativeShellController = controller
      window?.rootViewController = controller
      window?.backgroundColor = .systemBackground
      window?.makeKeyAndVisible()
      return
    }

    let controller = UIViewController()
    controller.view.backgroundColor = .systemBackground
    let label = UILabel()
    label.text = "Mensura requires iOS 26 for its native dashboard."
    label.textAlignment = .center
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    controller.view.addSubview(label)
    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor, constant: 30),
      label.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor, constant: -30),
      label.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor),
    ])
    nativeShellController = controller
    window?.rootViewController = controller
    window?.makeKeyAndVisible()
  }
}

// MARK: - Native iOS 26 shell

@available(iOS 26.0, *)
private enum MensuraTab: Hashable {
  case home
  case analytics
  case more
  case add
}

@available(iOS 26.0, *)
private struct MensuraNativeTabShell: View {
  @ObservedObject var store: MensuraStore

  @State private var selection = MensuraTab.home
  @State private var previousSelection = MensuraTab.home
  @State private var isAddMenuPresented = false
  @State private var activeAddRoute: AddRoute?

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .bottomTrailing) {
        TabView(selection: $selection) {
          Tab(value: MensuraTab.home) {
            MensuraHomeView(store: store)
          } label: {
            Label {
              Text("Home")
            } icon: {
              AnimatedTabIcon(
                outline: "HomeTabIcon",
                filled: "HomeTabIconFilled",
                isSelected: selection == .home
              )
            }
          }

          Tab(value: MensuraTab.analytics) {
            MensuraAnalyticsView(store: store)
          } label: {
            Label {
              Text("Analytics")
            } icon: {
              AnimatedTabIcon(
                outline: "AnalyticsTabIcon",
                filled: "AnalyticsTabIconFilled",
                isSelected: selection == .analytics
              )
            }
          }

          Tab(value: MensuraTab.more) {
            MensuraMoreView(store: store)
          } label: {
            Label {
              Text("More")
            } icon: {
              AnimatedSystemTabIcon(
                outline: "ellipsis.circle",
                filled: "ellipsis.circle.fill",
                isSelected: selection == .more
              )
            }
          }

          // The search-role tab reserves Apple's detached iOS 26 position.
          // Its content is covered by our explicit black action button below.
          Tab(value: MensuraTab.add, role: .search) {
            Color.clear
          } label: {
            Label("Add", systemImage: "plus")
              .opacity(0.001)
          }
        }
        .tabBarMinimizeBehavior(.never)
        .tint(.black)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .onChange(of: selection) { _, newValue in
          if newValue == .add {
            selection = previousSelection
            toggleAddMenu()
          } else {
            previousSelection = newValue
          }
        }

        if isAddMenuPresented {
          Color.black.opacity(0.24)
            .ignoresSafeArea()
            .onTapGesture { closeAddMenu() }
            .transition(.opacity)

          AddQuickMenuCard { route in
            closeAddMenu()
            DispatchQueue.main.async { activeAddRoute = route }
          }
          .padding(.horizontal, 14)
          .padding(.bottom, 96)
          .transition(.move(edge: .bottom).combined(with: .opacity))
        }

        Button(action: toggleAddMenu) {
          Image(systemName: "plus")
            .font(.system(size: 27, weight: .medium))
            .foregroundStyle(.white)
            .rotationEffect(.degrees(isAddMenuPresented ? 45 : 0))
            .frame(width: 66, height: 66)
            .background(Color.black, in: Circle())
            .shadow(color: .black.opacity(0.14), radius: 13, y: 7)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel(isAddMenuPresented ? "Close add menu" : "Add")
        .padding(.trailing, 14)
        .padding(.bottom, 8)
        .animation(.smooth(duration: 0.26), value: isAddMenuPresented)
      }
      .overlay(alignment: .top) {
        // Keep scrolling nutrition content out of the Dynamic Island/status bar.
        Color.white
          .frame(height: max(geometry.safeAreaInsets.top, 0))
          .ignoresSafeArea(edges: .top)
          .allowsHitTesting(false)
      }
      .animation(.smooth(duration: 0.28), value: isAddMenuPresented)
      .fullScreenCover(item: $activeAddRoute) { route in
        AddDestinationView(route: route, store: store)
      }
    }
  }

  private func toggleAddMenu() {
    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    withAnimation(.smooth(duration: 0.28)) {
      isAddMenuPresented.toggle()
    }
  }

  private func closeAddMenu() {
    withAnimation(.smooth(duration: 0.24)) {
      isAddMenuPresented = false
    }
  }
}

@available(iOS 26.0, *)
private struct AnimatedTabIcon: View {
  let outline: String
  let filled: String
  let isSelected: Bool

  var body: some View {
    ZStack {
      Image(outline)
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
      Image(filled)
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .mask {
          VStack(spacing: 0) {
            Spacer(minLength: 0)
            Rectangle()
              .frame(height: isSelected ? 25 : 0)
          }
        }
    }
    .frame(width: 25, height: 25)
    .animation(.smooth(duration: 0.28), value: isSelected)
  }
}

@available(iOS 26.0, *)
private struct AnimatedSystemTabIcon: View {
  let outline: String
  let filled: String
  let isSelected: Bool

  var body: some View {
    ZStack {
      Image(systemName: outline)
      Image(systemName: filled)
        .mask {
          VStack(spacing: 0) {
            Spacer(minLength: 0)
            Rectangle()
              .frame(height: isSelected ? 25 : 0)
          }
        }
    }
    .frame(width: 25, height: 25)
    .animation(.smooth(duration: 0.28), value: isSelected)
  }
}

// MARK: - Home dashboard

@available(iOS 26.0, *)
private struct MensuraHomeView: View {
  @ObservedObject var store: MensuraStore

  @State private var isEditingDashboard = false
  @State private var isWaterPickerPresented = false
  @State private var isCardLibraryPresented = false

  private var visibleCards: [DashboardCard] {
    store.dashboardCards.filter { $0 != .empty }
  }

  private var primaryCards: [DashboardCard] {
    Array(visibleCards.prefix(2))
  }

  private var secondaryCards: [DashboardCard] {
    Array(visibleCards.dropFirst(2))
  }

  var body: some View {
    ScrollView(.vertical) {
      LazyVStack(spacing: 0) {
        NutritionPanel(store: store)

        VStack(alignment: .leading, spacing: 12) {
          if isEditingDashboard { editBanner }

          if !primaryCards.isEmpty {
            dashboardSectionTitle("Water & Weight")
            dashboardGrid(primaryCards)
          }

          if !secondaryCards.isEmpty {
            dashboardSectionTitle("Steps & anything")
            dashboardGrid(secondaryCards)
          }

          if isEditingDashboard {
            Button {
              isCardLibraryPresented = true
            } label: {
              Label("Add a dashboard card", systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.bordered)
            .tint(.black)
          }

          Color.clear
            .frame(height: 140)
            .contentShape(Rectangle())
            .accessibilityLabel("Dashboard background")
            .onLongPressGesture(minimumDuration: 5) { enterEditMode() }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .background(
          Color(red: 248 / 255, green: 246 / 255, blue: 249 / 255)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 5) { enterEditMode() }
        )
        .animation(.smooth(duration: 0.32), value: visibleCards)
      }
    }
    .scrollIndicators(.hidden)
    .background(Color(red: 248 / 255, green: 246 / 255, blue: 249 / 255))
    .sheet(isPresented: $isWaterPickerPresented) {
      WaterAmountPicker(store: store)
        .presentationDetents([.height(390)])
        .presentationDragIndicator(.visible)
    }
    .sheet(isPresented: $isCardLibraryPresented) {
      DashboardCardLibrary(store: store)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    .task { store.refreshStepsFromDevice() }
  }

  private var editBanner: some View {
    HStack(spacing: 12) {
      Image(systemName: "rectangle.3.group")
        .font(.title3)
      VStack(alignment: .leading, spacing: 2) {
        Text("Edit Dashboard").font(.headline)
        Text("Drag cards to move them, or hide and add cards.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button("Done") {
        withAnimation(.snappy) { isEditingDashboard = false }
      }
      .fontWeight(.semibold)
    }
    .padding(14)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
  }

  private func dashboardSectionTitle(_ title: String) -> some View {
    Text(title)
      .font(.system(size: 24, weight: .medium))
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 7)
      .contentShape(Rectangle())
      .onLongPressGesture(minimumDuration: 5) { enterEditMode() }
  }

  @ViewBuilder
  private func dashboardGrid(_ cards: [DashboardCard]) -> some View {
    Grid(horizontalSpacing: 10, verticalSpacing: 10) {
      ForEach(Array(stride(from: 0, to: cards.count, by: 2)), id: \.self) { index in
        GridRow {
          if index + 1 < cards.count {
            dashboardCardCell(cards[index])
            dashboardCardCell(cards[index + 1])
          } else {
            dashboardCardCell(cards[index])
              .gridCellColumns(2)
          }
        }
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func dashboardCardCell(_ card: DashboardCard) -> some View {
    dashboardCard(card)
      .frame(maxWidth: .infinity)
      .frame(height: 200)
      .overlay(alignment: .topTrailing) {
        if isEditingDashboard {
          editControls(for: card)
        }
      }
      .modifier(DashboardReorderModifier(card: card, isEditing: isEditingDashboard) { source, target in
        withAnimation(.smooth(duration: 0.28)) {
          store.moveCard(source, before: target)
        }
      })
      .sensoryFeedback(.selection, trigger: isEditingDashboard)
  }

  @ViewBuilder
  private func dashboardCard(_ card: DashboardCard) -> some View {
    switch card {
    case .weight:
      WeightCard(store: store)
    case .water:
      WaterCard(store: store) { isWaterPickerPresented = true }
    case .steps:
      StepsCard(store: store)
    case .empty:
      EmptyDashboardCard(isEditing: isEditingDashboard) {
        isCardLibraryPresented = true
      }
    case .meals:
      MealsCard(store: store)
    case .weightTrend:
      WeightTrendCard(store: store)
    case .sleep:
      SleepCard()
    }
  }

  private func editControls(for card: DashboardCard) -> some View {
    HStack(spacing: 5) {
      Image(systemName: "line.3.horizontal")
        .font(.caption.weight(.bold))
        .frame(width: 30, height: 30)
        .background(.regularMaterial, in: Circle())
      Button(role: .destructive) { store.hideCard(card) } label: {
        Image(systemName: "minus.circle.fill")
          .font(.title3)
      }
      .frame(width: 30, height: 30)
      .background(.regularMaterial, in: Circle())
    }
    .padding(8)
  }

  private func enterEditMode() {
    guard !isEditingDashboard else { return }
    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    withAnimation(.snappy) { isEditingDashboard = true }
  }
}

@available(iOS 26.0, *)
private struct DashboardReorderModifier: ViewModifier {
  let card: DashboardCard
  let isEditing: Bool
  let onMove: (DashboardCard, DashboardCard) -> Void

  @ViewBuilder
  func body(content: Content) -> some View {
    if isEditing {
      content
        .draggable(card.rawValue) {
          Text(card.title)
            .font(.headline)
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .dropDestination(for: String.self) { items, _ in
          guard
            let raw = items.first,
            let source = DashboardCard(rawValue: raw)
          else { return false }
          onMove(source, card)
          return true
        }
    } else {
      content
    }
  }
}

@available(iOS 26.0, *)
private struct NutritionPanel: View {
  @ObservedObject var store: MensuraStore

  private let calorieBlue = Color(red: 92 / 255, green: 156 / 255, blue: 252 / 255)
  private let track = Color(red: 248 / 255, green: 246 / 255, blue: 247 / 255)

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(Self.dateFormatter.string(from: Date()).uppercased())
        .font(.system(size: 15))
        .foregroundStyle(.secondary)
      Text("Today")
        .font(.system(size: 29, weight: .semibold))
        .tracking(-0.7)

      HStack(spacing: 0) {
        metric(store.caloriesConsumed, label: "Eaten")

        ZStack {
          Circle()
            .trim(from: 0.10, to: 0.90)
            .stroke(track, style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .rotationEffect(.degrees(90))
          Circle()
            .trim(from: 0.10, to: 0.10 + 0.80 * calorieProgress)
            .stroke(calorieBlue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .rotationEffect(.degrees(90))
          VStack(spacing: 5) {
            Text(store.caloriesRemaining.formatted())
              .font(.system(size: 34, weight: .regular))
              .tracking(-0.8)
              .contentTransition(.numericText())
            Text("Remaining")
              .font(.system(size: 16))
              .foregroundStyle(.secondary)
          }
        }
        .frame(width: 168, height: 168)

        metric(store.calorieTarget, label: "Target")
      }
      .frame(height: 174)
      .padding(.top, 17)

      HStack(spacing: 28) {
        MacroMetric(
          title: "Protein",
          value: store.protein,
          target: store.proteinTarget,
          color: Color(red: 253 / 255, green: 135 / 255, blue: 101 / 255)
        )
        MacroMetric(
          title: "Fat",
          value: store.fat,
          target: store.fatTarget,
          color: Color(red: 252 / 255, green: 197 / 255, blue: 74 / 255)
        )
        MacroMetric(
          title: "Carbs",
          value: store.carbs,
          target: store.carbsTarget,
          color: Color(red: 76 / 255, green: 176 / 255, blue: 121 / 255)
        )
      }
      .padding(.top, 8)
    }
    .padding(.horizontal, 14)
    .padding(.top, 16)
    .padding(.bottom, 28)
    .background(Color(uiColor: .systemBackground))
  }

  private var calorieProgress: Double {
    guard store.calorieTarget > 0 else { return 0 }
    return min(max(Double(store.caloriesConsumed) / Double(store.calorieTarget), 0), 1)
  }

  private func metric(_ value: Int, label: String) -> some View {
    VStack(spacing: 4) {
      Text(value.formatted())
        .font(.system(size: 22, weight: .medium))
        .contentTransition(.numericText())
      Text(label)
        .font(.system(size: 15))
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
  }

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "EEEE, d MMMM"
    return formatter
  }()
}

@available(iOS 26.0, *)
private struct MacroMetric: View {
  let title: String
  let value: Double
  let target: Double
  let color: Color

  var body: some View {
    VStack(spacing: 6) {
      Text(title)
        .font(.system(size: 15))
        .foregroundStyle(.secondary)
      SmoothProgressBar(progress: target > 0 ? value / target : 0, color: color)
        .frame(height: 6)
      Text("\(Int(value)) / \(Int(target))g")
        .font(.system(size: 14, weight: .medium))
        .monospacedDigit()
    }
    .frame(maxWidth: .infinity)
  }
}

@available(iOS 26.0, *)
private struct SmoothProgressBar: View {
  let progress: Double
  let color: Color

  var body: some View {
    GeometryReader { proxy in
      let width = proxy.size.width * min(max(progress, 0), 1)
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color(red: 248 / 255, green: 246 / 255, blue: 247 / 255))
        if progress > 0 {
          Capsule()
            .fill(color)
            .frame(width: max(width, proxy.size.height))
            .transition(.scale(scale: 0, anchor: .leading).combined(with: .opacity))
        }
      }
      .animation(.smooth(duration: 0.34), value: progress)
    }
    .clipShape(Capsule())
  }
}

// MARK: Dashboard cards

@available(iOS 26.0, *)
private struct DashboardCardSurface<Content: View>: View {
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    content
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .shadow(color: .black.opacity(0.08), radius: 4)
  }
}

@available(iOS 26.0, *)
private struct WeightCard: View {
  @ObservedObject var store: MensuraStore

  var body: some View {
    DashboardCardSurface {
      VStack(spacing: 5) {
        Text("Weight").font(.system(size: 17, weight: .semibold))
        Text("Goal \(store.weightGoalKg, specifier: "%.0f") kg")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
        ZStack {
          Circle()
            .trim(from: 0.08, to: 0.92)
            .stroke(Color(red: 238 / 255, green: 205 / 255, blue: 250 / 255), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .rotationEffect(.degrees(90))
          Circle()
            .trim(from: 0.08, to: 0.08 + 0.84 * weightProgress)
            .stroke(Color(red: 175 / 255, green: 51 / 255, blue: 220 / 255), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .rotationEffect(.degrees(90))
          Text("\(store.weightKg, specifier: "%.0f") kg")
            .font(.system(size: 18, weight: .medium))
            .contentTransition(.numericText())
        }
        .frame(width: 118, height: 96)
      }
      .padding(10)
    }
  }

  private var weightProgress: Double {
    guard store.weightGoalKg > 0 else { return 0 }
    return min(max(store.weightKg / store.weightGoalKg, 0), 1)
  }
}

@available(iOS 26.0, *)
private struct WaterCard: View {
  @ObservedObject var store: MensuraStore
  let presentPicker: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    DashboardCardSurface {
      GeometryReader { proxy in
        HStack(spacing: 0) {
          VStack(spacing: 2) {
            Text("Water").font(.system(size: 17, weight: .semibold))
            Text("\(store.waterMl.formatted()) ml")
              .font(.system(size: 18, weight: .semibold))
              .contentTransition(.numericText())
            Text("Goal \(store.waterGoalMl.formatted()) ml")
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
            Spacer()
            WaterQuickAddButton(
              amount: store.quickWaterMl,
              onTap: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.snappy) { store.addWater(store.quickWaterMl) }
              },
              onLongPress: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                presentPicker()
              }
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 22)
          }
          .padding(.top, 8)
          .frame(width: proxy.size.width - 31)

          WaterGauge(
            progress: waterProgress,
            reduceMotion: reduceMotion
          )
          .frame(width: 31)
        }
      }
    }
  }

  private var waterProgress: Double {
    guard store.waterGoalMl > 0 else { return 0 }
    return min(max(Double(store.waterMl) / Double(store.waterGoalMl), 0), 1)
  }
}

@available(iOS 26.0, *)
private struct WaterQuickAddButton: View {
  let amount: Int
  let onTap: () -> Void
  let onLongPress: () -> Void

  var body: some View {
    Text("+\(amount)ml")
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .frame(height: 31)
      .background(Color(red: 0 / 255, green: 112 / 255, blue: 242 / 255), in: Capsule())
      .contentShape(Capsule())
      .accessibilityAddTraits(.isButton)
      .accessibilityHint("Tap to add. Press and hold to choose a different amount.")
      .gesture(
        LongPressGesture(minimumDuration: 0.55)
          .exclusively(before: TapGesture())
          .onEnded { value in
            switch value {
            case .first(true): onLongPress()
            case .second: onTap()
            default: break
            }
          }
      )
  }
}

@available(iOS 26.0, *)
private struct WaterGauge: View {
  let progress: Double
  let reduceMotion: Bool

  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
      let phase = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate * 1.15
      ZStack {
        Color(red: 186 / 255, green: 217 / 255, blue: 254 / 255)
        WaterWaveShape(progress: progress, phase: phase)
          .fill(Color(red: 1 / 255, green: 102 / 255, blue: 237 / 255))
        VStack {
          ForEach(0..<7, id: \.self) { index in
            Capsule()
              .fill(index.isMultiple(of: 2) ? Color.white.opacity(0.48) : Color.blue.opacity(0.23))
              .frame(width: index.isMultiple(of: 2) ? 10 : 6, height: 1.4)
            if index < 6 { Spacer() }
          }
        }
        .padding(.vertical, 18)
      }
      .clipped()
    }
  }
}

@available(iOS 26.0, *)
private struct WaterWaveShape: Shape {
  let progress: Double
  let phase: Double

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let top = rect.height * (1 - min(max(progress, 0), 1))
    path.move(to: CGPoint(x: 0, y: top))
    for x in stride(from: 0.0, through: rect.width, by: 1.0) {
      let normalized = x / max(rect.width, 1)
      let y = top + sin(normalized * .pi * 2 + phase) * 1.7
      path.addLine(to: CGPoint(x: x, y: y))
    }
    path.addLine(to: CGPoint(x: rect.width, y: rect.height))
    path.addLine(to: CGPoint(x: 0, y: rect.height))
    path.closeSubpath()
    return path
  }
}

@available(iOS 26.0, *)
private struct StepsCard: View {
  @ObservedObject var store: MensuraStore

  var body: some View {
    DashboardCardSurface {
      VStack(spacing: 5) {
        Text("\(store.steps.formatted()) Steps")
          .font(.system(size: 19, weight: .semibold))
        Text("Goal \(store.stepsGoal.formatted())")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
        ZStack {
          Circle()
            .stroke(Color(red: 242 / 255, green: 250 / 255, blue: 205 / 255), lineWidth: 8)
          Circle()
            .trim(from: 0, to: stepsProgress)
            .stroke(Color(red: 188 / 255, green: 235 / 255, blue: 0), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .rotationEffect(.degrees(-90))
          Text("0 km | 0 cal")
            .font(.system(size: 13, weight: .medium))
        }
        .frame(width: 112, height: 112)
      }
      .padding(10)
    }
  }

  private var stepsProgress: Double {
    guard store.stepsGoal > 0 else { return 0 }
    return min(max(Double(store.steps) / Double(store.stepsGoal), 0), 1)
  }
}

@available(iOS 26.0, *)
private struct EmptyDashboardCard: View {
  let isEditing: Bool
  let onAdd: () -> Void

  var body: some View {
    DashboardCardSurface {
      if isEditing {
        Button(action: onAdd) {
          VStack(spacing: 8) {
            Image(systemName: "plus.circle")
              .font(.title2)
            Text("Add card")
              .font(.subheadline.weight(.semibold))
          }
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      } else {
        Color.clear
      }
    }
  }
}

@available(iOS 26.0, *)
private struct MealsCard: View {
  @ObservedObject var store: MensuraStore

  var body: some View {
    DashboardCardSurface {
      VStack(alignment: .leading, spacing: 9) {
        Text("Meals").font(.headline)
        Text("\(store.foodEntries.count) logged today")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        ForEach(store.foodEntries.prefix(3)) { entry in
          HStack {
            Text(entry.name).lineLimit(1)
            Spacer()
            Text("\(entry.calories)").monospacedDigit()
          }
          .font(.caption)
        }
        if store.foodEntries.isEmpty {
          Text("No food logged yet")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      .padding(14)
    }
  }
}

@available(iOS 26.0, *)
private struct WeightTrendCard: View {
  @ObservedObject var store: MensuraStore

  var body: some View {
    DashboardCardSurface {
      VStack(alignment: .leading, spacing: 8) {
        Text("Weight trend").font(.headline)
        Text("Last 7 days")
          .font(.caption)
          .foregroundStyle(.secondary)
        Chart(Self.samples) { item in
          LineMark(
            x: .value("Day", item.day),
            y: .value("Weight", item.value)
          )
          .interpolationMethod(.catmullRom)
          .foregroundStyle(.purple)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        Text("\(store.weightKg, specifier: "%.1f") kg")
          .font(.title3.weight(.semibold))
      }
      .padding(14)
    }
  }

  private static let samples = [
    WeeklyValue(day: "M", value: 61.1),
    WeeklyValue(day: "T", value: 60.8),
    WeeklyValue(day: "W", value: 60.7),
    WeeklyValue(day: "T", value: 60.4),
    WeeklyValue(day: "F", value: 60.2),
    WeeklyValue(day: "S", value: 60.1),
    WeeklyValue(day: "S", value: 60.0),
  ]
}

@available(iOS 26.0, *)
private struct SleepCard: View {
  var body: some View {
    DashboardCardSurface {
      VStack(spacing: 8) {
        Image(systemName: "moon.stars.fill")
          .font(.title)
          .foregroundStyle(.indigo)
        Text("Sleep").font(.headline)
        Text("7 h 42 m")
          .font(.title3.weight(.semibold))
        Text("Last night")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}

@available(iOS 26.0, *)
private struct WaterAmountPicker: View {
  @ObservedObject var store: MensuraStore
  @Environment(\.dismiss) private var dismiss
  @State private var selectedAmount: Int

  private let amounts = [150, 200, 250, 330, 400, 500, 750, 1000]

  init(store: MensuraStore) {
    self.store = store
    _selectedAmount = State(initialValue: store.quickWaterMl)
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 14) {
        Picker("Water amount", selection: $selectedAmount) {
          ForEach(amounts, id: \.self) { amount in
            Text("\(amount) ml").tag(amount)
          }
        }
        .pickerStyle(.wheel)

        Button {
          UIImpactFeedbackGenerator(style: .light).impactOccurred()
          withAnimation(.snappy) {
            store.addWater(selectedAmount, useAsShortcut: true)
          }
          dismiss()
        } label: {
          Text("Add \(selectedAmount) ml")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
        .padding(.horizontal, 18)
      }
      .navigationTitle("Add Water")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
  }
}

@available(iOS 26.0, *)
private struct DashboardCardLibrary: View {
  @ObservedObject var store: MensuraStore
  @Environment(\.dismiss) private var dismiss

  private var hiddenCards: [DashboardCard] {
    DashboardCard.allCases.filter { card in
      card != .empty && !store.dashboardCards.contains(card)
    }
  }

  var body: some View {
    NavigationStack {
      List(hiddenCards) { card in
        Button {
          store.showCard(card)
          dismiss()
        } label: {
          Label(card.title, systemImage: symbol(for: card))
        }
      }
      .overlay {
        if hiddenCards.isEmpty {
          ContentUnavailableView("All cards are visible", systemImage: "rectangle.3.group")
        }
      }
      .navigationTitle("Add Card")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
      }
    }
  }

  private func symbol(for card: DashboardCard) -> String {
    switch card {
    case .weight: return "scalemass"
    case .water: return "drop"
    case .steps: return "figure.walk"
    case .meals: return "fork.knife"
    case .weightTrend: return "chart.line.uptrend.xyaxis"
    case .sleep: return "moon.stars"
    case .empty: return "square"
    }
  }
}

// MARK: - Analytics and settings

@available(iOS 26.0, *)
private struct MensuraAnalyticsView: View {
  @ObservedObject var store: MensuraStore

  private let calories = [
    WeeklyValue(day: "Mon", value: 2230),
    WeeklyValue(day: "Tue", value: 2540),
    WeeklyValue(day: "Wed", value: 2410),
    WeeklyValue(day: "Thu", value: 2660),
    WeeklyValue(day: "Fri", value: 2280),
    WeeklyValue(day: "Sat", value: 2710),
    WeeklyValue(day: "Sun", value: 100),
  ]

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 14) {
          analyticsCard(title: "Calories", subtitle: "This week") {
            Chart(calories) { item in
              BarMark(
                x: .value("Day", item.day),
                y: .value("Calories", item.value)
              )
              .cornerRadius(8)
              .foregroundStyle(Color(red: 92 / 255, green: 156 / 255, blue: 252 / 255))
            }
            .chartYAxis(.hidden)
            .frame(height: 170)
          }

          analyticsCard(title: "Macros", subtitle: "Daily progress") {
            VStack(spacing: 14) {
              analyticMacro("Protein", store.protein, store.proteinTarget, Color(red: 253 / 255, green: 135 / 255, blue: 101 / 255))
              analyticMacro("Fat", store.fat, store.fatTarget, Color(red: 252 / 255, green: 197 / 255, blue: 74 / 255))
              analyticMacro("Carbs", store.carbs, store.carbsTarget, Color(red: 76 / 255, green: 176 / 255, blue: 121 / 255))
            }
          }

          analyticsCard(title: "Hydration", subtitle: "Today") {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text("\(store.waterMl.formatted()) ml")
                  .font(.title2.weight(.semibold))
                Text("of \(store.waterGoalMl.formatted()) ml")
                  .foregroundStyle(.secondary)
              }
              Spacer()
              ProgressView(value: Double(store.waterMl), total: Double(max(store.waterGoalMl, 1)))
                .progressViewStyle(.circular)
                .tint(.blue)
            }
          }
        }
        .padding(16)
        .padding(.bottom, 90)
      }
      .background(Color(red: 248 / 255, green: 246 / 255, blue: 249 / 255))
      .navigationTitle("Analytics")
    }
  }

  private func analyticsCard<Content: View>(
    title: String,
    subtitle: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.title3.weight(.semibold))
        Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
      }
      content()
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background, in: RoundedRectangle(cornerRadius: 16))
  }

  private func analyticMacro(_ name: String, _ value: Double, _ target: Double, _ color: Color) -> some View {
    VStack(spacing: 6) {
      HStack {
        Text(name).font(.subheadline)
        Spacer()
        Text("\(Int(value)) / \(Int(target)) g")
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(.secondary)
      }
      SmoothProgressBar(progress: target > 0 ? value / target : 0, color: color)
        .frame(height: 10)
    }
  }
}

@available(iOS 26.0, *)
private struct MensuraMoreView: View {
  @ObservedObject var store: MensuraStore

  var body: some View {
    NavigationStack {
      List {
        Section {
          NavigationLink {
            GoalSettingsView(store: store)
          } label: {
            Label("Goals", systemImage: "target")
          }
          NavigationLink {
            FoodHistoryView(store: store)
          } label: {
            Label("Food history", systemImage: "fork.knife")
          }
        }

        Section("Reminders") {
          Toggle(
            "Water reminders",
            isOn: Binding(
              get: { store.waterReminders },
              set: { store.setWaterReminders($0) }
            )
          )
          Toggle(
            "Calorie reminders",
            isOn: Binding(
              get: { store.calorieReminders },
              set: { store.setCalorieReminders($0) }
            )
          )
        }

        Section("Preferences") {
          Toggle(
            "Metric units",
            isOn: Binding(
              get: { store.metricUnits },
              set: { store.setMetricUnits($0) }
            )
          )
          NavigationLink {
            Text("Mensura 0.3.0")
              .navigationTitle("About")
          } label: {
            Label("About Mensura", systemImage: "info.circle")
          }
        }
      }
      .navigationTitle("More")
    }
  }
}

@available(iOS 26.0, *)
private struct GoalSettingsView: View {
  @ObservedObject var store: MensuraStore
  @State private var waterGoal = ""
  @State private var weightGoal = ""

  var body: some View {
    Form {
      Section("Daily goals") {
        TextField("Water goal (ml)", text: $waterGoal)
          .keyboardType(.numberPad)
        TextField("Weight goal (kg)", text: $weightGoal)
          .keyboardType(.decimalPad)
        Button("Save goals") {
          if let water = Int(waterGoal) { store.setWaterGoal(water) }
          if let weight = Double(weightGoal) { store.setWeightGoal(weight) }
        }
      }
    }
    .navigationTitle("Goals")
    .onAppear {
      waterGoal = String(store.waterGoalMl)
      weightGoal = String(format: "%.0f", store.weightGoalKg)
    }
  }
}

@available(iOS 26.0, *)
private struct FoodHistoryView: View {
  @ObservedObject var store: MensuraStore

  var body: some View {
    List(store.foodEntries) { entry in
      VStack(alignment: .leading, spacing: 3) {
        HStack {
          Text(entry.name).font(.headline)
          Spacer()
          Text("\(entry.calories) kcal").font(.subheadline)
        }
        Text("P \(Int(entry.protein))g · F \(Int(entry.fat))g · C \(Int(entry.carbs))g")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .overlay {
      if store.foodEntries.isEmpty {
        ContentUnavailableView("No food logged", systemImage: "fork.knife")
      }
    }
    .navigationTitle("Food history")
  }
}

// MARK: - Add menu and food logging

@available(iOS 26.0, *)
private enum AddRoute: String, Hashable, CaseIterable, Identifiable {
  case food
  case calories
  case water
  case weight
  case activity

  var id: String { rawValue }

  var title: String {
    switch self {
    case .food: return "Log food"
    case .calories: return "Quick calories"
    case .water: return "Add water"
    case .weight: return "Log weight"
    case .activity: return "Log activity"
    }
  }

  var symbol: String {
    switch self {
    case .food: return "fork.knife"
    case .calories: return "flame"
    case .water: return "drop.fill"
    case .weight: return "scalemass"
    case .activity: return "figure.run"
    }
  }
}

@available(iOS 26.0, *)
private struct AddQuickMenuCard: View {
  let onSelect: (AddRoute) -> Void

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Add")
          .font(.system(size: 22, weight: .semibold))
        Spacer()
        Text("Choose what to log")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 16)

      Divider().padding(.leading, 18)

      ForEach(Array(AddRoute.allCases.enumerated()), id: \.element.id) { index, route in
        Button {
          UIImpactFeedbackGenerator(style: .soft).impactOccurred()
          onSelect(route)
        } label: {
          HStack(spacing: 14) {
            Image(systemName: route.symbol)
              .font(.system(size: 18, weight: .medium))
              .frame(width: 28)
            Text(route.title)
              .font(.system(size: 17, weight: .medium))
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.tertiary)
          }
          .foregroundStyle(.black)
          .frame(height: 52)
          .padding(.horizontal, 18)
        }
        .buttonStyle(.plain)

        if index < AddRoute.allCases.count - 1 {
          Divider().padding(.leading, 60)
        }
      }
    }
    .fixedSize(horizontal: false, vertical: true)
    .frame(maxWidth: 390)
    .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(Color.black.opacity(0.06), lineWidth: 0.7)
    }
    .shadow(color: .black.opacity(0.16), radius: 24, y: 12)
  }
}

@available(iOS 26.0, *)
private struct AddDestinationView: View {
  let route: AddRoute
  @ObservedObject var store: MensuraStore
  @Environment(\.dismiss) private var dismiss

  @ViewBuilder
  var body: some View {
    switch route {
    case .food:
      FoodLoggingView(store: store)
    case .water:
      WaterAmountPicker(store: store)
    case .calories, .weight, .activity:
      NavigationStack {
        destinationContent
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button { dismiss() } label: {
                Image(systemName: "xmark")
              }
            }
          }
      }
    }
  }

  @ViewBuilder
  private var destinationContent: some View {
    switch route {
    case .calories: QuickCaloriesView(store: store)
    case .weight: LogWeightView(store: store)
    case .activity: LogActivityView(store: store)
    default: EmptyView()
    }
  }
}

@available(iOS 26.0, *)
private enum MealSlot: String, CaseIterable, Identifiable {
  case breakfast = "Breakfast"
  case lunch = "Lunch"
  case dinner = "Dinner"
  case snacks = "Snack"

  var id: String { rawValue }
  var title: String { self == .snacks ? "Snacks" : rawValue }
}

@available(iOS 26.0, *)
private struct FoodLoggingView: View {
  @ObservedObject var store: MensuraStore
  @Environment(\.dismiss) private var dismiss
  @State private var query = ""
  @State private var results: [FoodEntry] = Self.starterFoods
  @State private var isSearching = false
  @State private var isScannerPresented = false
  @State private var selectedMeal = MealSlot.breakfast
  @State private var lastAddedID: UUID?

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        searchField
          .padding(.horizontal, 16)
          .padding(.top, 10)

        mealTabs
          .padding(.horizontal, 16)
          .padding(.top, 13)

        ScrollView {
          LazyVStack(spacing: 0) {
            mealSummary
              .padding(.horizontal, 16)
              .padding(.vertical, 16)

            HStack {
              Text(query.isEmpty ? "Suggested foods" : "Search results")
                .font(.system(size: 20, weight: .semibold))
              Spacer()
              Text("per serving")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 7)

            ForEach(results) { food in
              foodRow(food)
              Divider().padding(.leading, 18)
            }
          }
        }
      }
      .background(Color.white)
      .navigationTitle("Add Food")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button { dismiss() } label: {
            Image(systemName: "xmark")
          }
        }
      }
      .sheet(isPresented: $isScannerPresented) {
        BarcodeLookupFlow(store: store, meal: selectedMeal)
      }
    }
  }

  private var searchField: some View {
    HStack(spacing: 9) {
      Button { isScannerPresented = true } label: {
        Image(systemName: "barcode.viewfinder")
          .font(.system(size: 19, weight: .medium))
          .foregroundStyle(.black)
          .frame(width: 34, height: 34)
      }
      TextField("Search food", text: $query)
        .textInputAutocapitalization(.never)
        .submitLabel(.search)
        .onSubmit { Task { await search() } }
      if isSearching {
        ProgressView().controlSize(.small)
      } else if !query.isEmpty {
        Button {
          query = ""
          results = Self.starterFoods
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.tertiary)
        }
      }
    }
    .padding(.horizontal, 10)
    .frame(height: 48)
    .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
  }

  private var mealTabs: some View {
    HStack(spacing: 0) {
      ForEach(MealSlot.allCases) { meal in
        Button {
          UISelectionFeedbackGenerator().selectionChanged()
          withAnimation(.smooth(duration: 0.24)) { selectedMeal = meal }
        } label: {
          VStack(spacing: 8) {
            Text(meal.title)
              .font(.system(size: 14, weight: selectedMeal == meal ? .semibold : .regular))
              .foregroundStyle(selectedMeal == meal ? Color.black : Color.secondary)
            Capsule()
              .fill(selectedMeal == meal ? Color.black : Color.clear)
              .frame(height: 2.5)
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
      }
    }
    .overlay(alignment: .bottom) { Divider() }
  }

  private var mealSummary: some View {
    HStack(spacing: 14) {
      ZStack {
        Circle().fill(Color.black)
        Image(systemName: "fork.knife")
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(.white)
      }
      .frame(width: 42, height: 42)

      VStack(alignment: .leading, spacing: 3) {
        Text(selectedMeal.title)
          .font(.headline)
        Text("\(selectedMealEntries.count) items logged")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Text("\(selectedMealCalories) kcal")
        .font(.system(size: 17, weight: .semibold))
        .contentTransition(.numericText())
    }
    .padding(14)
    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
  }

  private func foodRow(_ food: FoodEntry) -> some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(food.name)
          .font(.system(size: 16, weight: .medium))
        Text(food.brand.isEmpty ? "Food database" : food.brand)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Text("\(food.calories) kcal")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
      Button { add(food) } label: {
        Image(systemName: lastAddedID == food.id ? "checkmark" : "plus")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 32, height: 32)
          .background(Color.black, in: Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Add \(food.name) to \(selectedMeal.title)")
    }
    .padding(.horizontal, 18)
    .frame(minHeight: 68)
  }

  private var selectedMealEntries: [FoodEntry] {
    store.foodEntries.filter { $0.meal == selectedMeal.rawValue }
  }

  private var selectedMealCalories: Int {
    selectedMealEntries.reduce(0) { $0 + $1.calories }
  }

  private func add(_ food: FoodEntry) {
    var loggedFood = food
    loggedFood.id = UUID()
    loggedFood.meal = selectedMeal.rawValue
    store.addFood(loggedFood)
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    withAnimation(.smooth(duration: 0.2)) { lastAddedID = food.id }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
      if lastAddedID == food.id {
        withAnimation(.smooth(duration: 0.2)) { lastAddedID = nil }
      }
    }
  }

  private func search() async {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      results = Self.starterFoods
      return
    }
    isSearching = true
    defer { isSearching = false }
    do {
      let remote = try await FoodLookupService.search(query: trimmed)
      results = remote.isEmpty
        ? Self.starterFoods.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
        : remote
    } catch {
      results = Self.starterFoods.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
  }

  private static let starterFoods = [
    FoodEntry(name: "Banana", calories: 105, protein: 1.3, fat: 0.4, carbs: 27),
    FoodEntry(name: "Chicken breast", calories: 165, protein: 31, fat: 3.6, carbs: 0),
    FoodEntry(name: "Greek yogurt", calories: 100, protein: 17, fat: 0.7, carbs: 6),
    FoodEntry(name: "White rice", calories: 205, protein: 4.3, fat: 0.4, carbs: 45),
  ]
}

@available(iOS 26.0, *)
private struct QuickCaloriesView: View {
  @ObservedObject var store: MensuraStore
  @Environment(\.dismiss) private var dismiss
  @State private var calories = ""
  @State private var note = ""

  var body: some View {
    Form {
      Section("Calories") {
        TextField("0", text: $calories)
          .keyboardType(.numberPad)
        TextField("Note (optional)", text: $note)
      }
      Button("Add calories") {
        guard let amount = Int(calories), amount > 0 else { return }
        store.addCalories(amount, note: note)
        dismiss()
      }
      .fontWeight(.semibold)
    }
    .navigationTitle("Quick Calories")
  }
}

@available(iOS 26.0, *)
private struct LogWeightView: View {
  @ObservedObject var store: MensuraStore
  @Environment(\.dismiss) private var dismiss
  @State private var value = ""

  var body: some View {
    Form {
      TextField("Weight in kg", text: $value)
        .keyboardType(.decimalPad)
      Button("Save weight") {
        guard let number = Double(value) else { return }
        store.setWeight(number)
        dismiss()
      }
      .fontWeight(.semibold)
    }
    .navigationTitle("Log Weight")
    .onAppear { value = String(format: "%.1f", store.weightKg) }
  }
}

@available(iOS 26.0, *)
private struct LogActivityView: View {
  @ObservedObject var store: MensuraStore
  @Environment(\.dismiss) private var dismiss
  @State private var steps = ""

  var body: some View {
    Form {
      TextField("Steps", text: $steps)
        .keyboardType(.numberPad)
      Button("Save activity") {
        guard let number = Int(steps), number >= 0 else { return }
        store.setSteps(number)
        dismiss()
      }
      .fontWeight(.semibold)
    }
    .navigationTitle("Log Activity")
  }
}

// MARK: Barcode and nutrition-label recognition

@available(iOS 26.0, *)
private struct BarcodeLookupFlow: View {
  @ObservedObject var store: MensuraStore
  let meal: MealSlot
  @Environment(\.dismiss) private var dismiss

  @State private var scannedCode: String?
  @State private var foundFood: FoodEntry?
  @State private var isLoading = false
  @State private var wasNotFound = false
  @State private var isNutritionCapturePresented = false

  var body: some View {
    NavigationStack {
      Group {
        if let food = foundFood {
          FoodConfirmationView(food: food) {
            var loggedFood = food
            loggedFood.id = UUID()
            loggedFood.meal = meal.rawValue
            store.addFood(loggedFood)
            dismiss()
          }
        } else if isLoading {
          VStack(spacing: 12) {
            ProgressView()
            Text("Looking up product…").foregroundStyle(.secondary)
          }
        } else if wasNotFound {
          ContentUnavailableView {
            Label("Product not found", systemImage: "barcode.viewfinder")
          } description: {
            Text("Photograph the nutrition label and Mensura will prepare an editable preview.")
          } actions: {
            Button("Scan nutrition label") { isNutritionCapturePresented = true }
              .buttonStyle(.borderedProminent)
          }
        } else {
          BarcodeScannerView { code in
            guard scannedCode == nil else { return }
            scannedCode = code
            Task { await lookup(code) }
          }
          .ignoresSafeArea()
          .overlay(alignment: .center) {
            RoundedRectangle(cornerRadius: 18)
              .stroke(.white, lineWidth: 2)
              .frame(width: 280, height: 170)
              .shadow(color: .black.opacity(0.4), radius: 8)
          }
        }
      }
      .navigationTitle("Scan Barcode")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
      }
      .sheet(isPresented: $isNutritionCapturePresented) {
        NutritionLabelCaptureView(store: store, meal: meal)
      }
    }
  }

  private func lookup(_ code: String) async {
    isLoading = true
    defer { isLoading = false }
    do {
      foundFood = try await FoodLookupService.lookup(barcode: code)
      wasNotFound = foundFood == nil
    } catch {
      wasNotFound = true
    }
  }
}

@available(iOS 26.0, *)
private struct FoodConfirmationView: View {
  let food: FoodEntry
  let onAdd: () -> Void

  var body: some View {
    Form {
      Section {
        LabeledContent("Product", value: food.name)
        if !food.brand.isEmpty { LabeledContent("Brand", value: food.brand) }
        LabeledContent("Calories", value: "\(food.calories) kcal")
        LabeledContent("Protein", value: String(format: "%.1f g", food.protein))
        LabeledContent("Fat", value: String(format: "%.1f g", food.fat))
        LabeledContent("Carbs", value: String(format: "%.1f g", food.carbs))
      }
      Button("Add to today", action: onAdd)
        .fontWeight(.semibold)
    }
    .navigationTitle("Product Preview")
  }
}

@available(iOS 26.0, *)
private enum FoodLookupService {
  private struct ProductResponse: Decodable {
    let status: Int?
    let product: Product?
  }

  private struct SearchResponse: Decodable {
    let products: [Product]?
  }

  private struct Product: Decodable {
    let productName: String?
    let brands: String?
    let code: String?
    let nutriments: Nutriments?

    enum CodingKeys: String, CodingKey {
      case productName = "product_name"
      case brands
      case code
      case nutriments
    }
  }

  private struct Nutriments: Decodable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let fat100g: Double?
    let carbohydrates100g: Double?

    enum CodingKeys: String, CodingKey {
      case energyKcal100g = "energy-kcal_100g"
      case proteins100g = "proteins_100g"
      case fat100g = "fat_100g"
      case carbohydrates100g = "carbohydrates_100g"
    }
  }

  static func lookup(barcode: String) async throws -> FoodEntry? {
    guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json") else {
      return nil
    }
    var request = URLRequest(url: url)
    request.setValue("Mensura-iOS/0.3", forHTTPHeaderField: "User-Agent")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
    let decoded = try JSONDecoder().decode(ProductResponse.self, from: data)
    guard decoded.status == 1, let product = decoded.product else { return nil }
    return entry(from: product)
  }

  static func search(query: String) async throws -> [FoodEntry] {
    var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")
    components?.queryItems = [
      URLQueryItem(name: "search_terms", value: query),
      URLQueryItem(name: "search_simple", value: "1"),
      URLQueryItem(name: "action", value: "process"),
      URLQueryItem(name: "json", value: "1"),
      URLQueryItem(name: "page_size", value: "20"),
    ]
    guard let url = components?.url else { return [] }
    var request = URLRequest(url: url)
    request.setValue("Mensura-iOS/0.3", forHTTPHeaderField: "User-Agent")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
    let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
    return (decoded.products ?? []).prefix(20).map(entry(from:))
  }

  private static func entry(from product: Product) -> FoodEntry {
    FoodEntry(
      name: product.productName?.isEmpty == false ? product.productName! : "Unknown product",
      brand: product.brands ?? "",
      calories: Int((product.nutriments?.energyKcal100g ?? 0).rounded()),
      protein: product.nutriments?.proteins100g ?? 0,
      fat: product.nutriments?.fat100g ?? 0,
      carbs: product.nutriments?.carbohydrates100g ?? 0,
      meal: "Snack",
      barcode: product.code
    )
  }
}

private struct BarcodeScannerView: UIViewControllerRepresentable {
  let onCode: (String) -> Void

  func makeUIViewController(context: Context) -> BarcodeScannerController {
    let controller = BarcodeScannerController()
    controller.onCode = onCode
    return controller
  }

  func updateUIViewController(_ uiViewController: BarcodeScannerController, context: Context) {}
}

private final class BarcodeScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
  var onCode: ((String) -> Void)?
  private let session = AVCaptureSession()
  private var previewLayer: AVCaptureVideoPreviewLayer?
  private var hasDeliveredCode = false

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    configureSession()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    previewLayer?.frame = view.bounds
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      self?.session.startRunning()
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    session.stopRunning()
  }

  private func configureSession() {
    guard
      let device = AVCaptureDevice.default(for: .video),
      let input = try? AVCaptureDeviceInput(device: device),
      session.canAddInput(input)
    else { return }
    session.addInput(input)

    let output = AVCaptureMetadataOutput()
    guard session.canAddOutput(output) else { return }
    session.addOutput(output)
    output.setMetadataObjectsDelegate(self, queue: .main)
    output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .qr]

    let layer = AVCaptureVideoPreviewLayer(session: session)
    layer.videoGravity = .resizeAspectFill
    view.layer.addSublayer(layer)
    previewLayer = layer
  }

  func metadataOutput(
    _ output: AVCaptureMetadataOutput,
    didOutput metadataObjects: [AVMetadataObject],
    from connection: AVCaptureConnection
  ) {
    guard
      !hasDeliveredCode,
      let readable = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
      let value = readable.stringValue
    else { return }
    hasDeliveredCode = true
    session.stopRunning()
    UINotificationFeedbackGenerator().notificationOccurred(.success)
    onCode?(value)
  }
}

private struct NutritionDraft {
  var name = "Scanned food"
  var calories = ""
  var protein = ""
  var fat = ""
  var carbs = ""

  var foodEntry: FoodEntry? {
    guard let caloriesValue = Int(calories) else { return nil }
    return FoodEntry(
      name: name.isEmpty ? "Scanned food" : name,
      calories: caloriesValue,
      protein: Double(protein) ?? 0,
      fat: Double(fat) ?? 0,
      carbs: Double(carbs) ?? 0,
      meal: "Snack"
    )
  }
}

@available(iOS 26.0, *)
private struct NutritionLabelCaptureView: View {
  @ObservedObject var store: MensuraStore
  let meal: MealSlot
  @Environment(\.dismiss) private var dismiss

  @State private var draft = NutritionDraft()
  @State private var isPickerPresented = false
  @State private var isReading = false
  @State private var didReadImage = false

  var body: some View {
    NavigationStack {
      Form {
        if !didReadImage {
          Section {
            Button {
              isPickerPresented = true
            } label: {
              Label("Photograph nutrition label", systemImage: "camera.viewfinder")
            }
            if isReading {
              HStack { ProgressView(); Text("Reading label…") }
            }
          }
        } else {
          Section("Check the result") {
            TextField("Food name", text: $draft.name)
            TextField("Calories", text: $draft.calories).keyboardType(.numberPad)
            TextField("Protein (g)", text: $draft.protein).keyboardType(.decimalPad)
            TextField("Fat (g)", text: $draft.fat).keyboardType(.decimalPad)
            TextField("Carbs (g)", text: $draft.carbs).keyboardType(.decimalPad)
          }
          Button("Add confirmed food") {
            guard let entry = draft.foodEntry else { return }
            var loggedFood = entry
            loggedFood.id = UUID()
            loggedFood.meal = meal.rawValue
            store.addFood(loggedFood)
            dismiss()
          }
          .fontWeight(.semibold)
        }
      }
      .navigationTitle("Nutrition Label")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
      }
      .sheet(isPresented: $isPickerPresented) {
        CameraImagePicker { image in
          Task { await read(image) }
        }
      }
    }
  }

  private func read(_ image: UIImage) async {
    isReading = true
    defer { isReading = false }
    guard let cgImage = image.cgImage else { return }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    let handler = VNImageRequestHandler(cgImage: cgImage)
    do {
      try handler.perform([request])
      let text = (request.results ?? [])
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: "\n")
      draft = NutritionLabelParser.parse(text)
      didReadImage = true
    } catch {
      didReadImage = true
    }
  }
}

private enum NutritionLabelParser {
  static func parse(_ text: String) -> NutritionDraft {
    var draft = NutritionDraft()
    draft.calories = match(in: text, patterns: ["calories?\\s*[:]?\\s*(\\d+)", "energy\\s*[:]?\\s*(\\d+)"]) ?? ""
    draft.protein = match(in: text, patterns: ["protein\\s*[:]?\\s*(\\d+(?:[\\.,]\\d+)?)"]) ?? ""
    draft.fat = match(in: text, patterns: ["total\\s+fat\\s*[:]?\\s*(\\d+(?:[\\.,]\\d+)?)", "fat\\s*[:]?\\s*(\\d+(?:[\\.,]\\d+)?)"]) ?? ""
    draft.carbs = match(in: text, patterns: ["(?:total\\s+)?carbohydrates?\\s*[:]?\\s*(\\d+(?:[\\.,]\\d+)?)", "carbs?\\s*[:]?\\s*(\\d+(?:[\\.,]\\d+)?)"]) ?? ""
    draft.protein = draft.protein.replacingOccurrences(of: ",", with: ".")
    draft.fat = draft.fat.replacingOccurrences(of: ",", with: ".")
    draft.carbs = draft.carbs.replacingOccurrences(of: ",", with: ".")
    return draft
  }

  private static func match(in text: String, patterns: [String]) -> String? {
    for pattern in patterns {
      guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
      let range = NSRange(text.startIndex..<text.endIndex, in: text)
      guard
        let result = regex.firstMatch(in: text, range: range),
        result.numberOfRanges > 1,
        let valueRange = Range(result.range(at: 1), in: text)
      else { continue }
      return String(text[valueRange])
    }
    return nil
  }
}

private struct CameraImagePicker: UIViewControllerRepresentable {
  let onImage: (UIImage) -> Void

  func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.delegate = context.coordinator
    picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
    return picker
  }

  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

  final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    let onImage: (UIImage) -> Void

    init(onImage: @escaping (UIImage) -> Void) {
      self.onImage = onImage
    }

    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      if let image = info[.originalImage] as? UIImage { onImage(image) }
      picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      picker.dismiss(animated: true)
    }
  }
}

import Combine
import Flutter
import SwiftUI
import UIKit

@MainActor
private final class MensuraShellModel: ObservableObject {
  @Published var isWaterSheetPresented = false
  @Published var pendingWaterAmount = 330
  @Published var lastAddedWaterAmount = 0

  var onWaterAdded: ((Int) -> Void)?

  func presentWaterPicker(currentAmount: Int) {
    pendingWaterAmount = currentAmount
    isWaterSheetPresented = true
  }

  func addWater() {
    lastAddedWaterAmount = pendingWaterAmount
    onWaterAdded?(pendingWaterAmount)
    isWaterSheetPresented = false
  }
}

class SceneDelegate: FlutterSceneDelegate {
  private weak var flutterViewController: FlutterViewController?
  private var nativeShellController: UIViewController?
  private var nativeChannel: FlutterMethodChannel?
  private let shellModel = MensuraShellModel()

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(
      scene,
      willConnectTo: session,
      options: connectionOptions
    )

    guard let flutterViewController =
      window?.rootViewController as? FlutterViewController
    else {
      return
    }

    self.flutterViewController = flutterViewController
    window?.backgroundColor = .systemBackground
    flutterViewController.view.backgroundColor = .systemBackground
    flutterViewController.overrideUserInterfaceStyle = .light
    flutterViewController.tabBarItem = UITabBarItem(
      title: "Home",
      image: UIImage(systemName: "house"),
      selectedImage: UIImage(systemName: "house.fill")
    )

    let channel = FlutterMethodChannel(
      name: "com.mensura/native_shell",
      binaryMessenger: flutterViewController.binaryMessenger
    )
    nativeChannel = channel
    shellModel.onWaterAdded = { [weak self] amount in
      self?.nativeChannel?.invokeMethod(
        "waterAmountSelected",
        arguments: amount
      )
    }

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }

      switch call.method {
      case "showTabs":
        self.showTabs()
        result(nil)
      case "showWaterPicker":
        let arguments = call.arguments as? [String: Any]
        let currentAmount = arguments?["current"] as? Int ?? 330
        if #available(iOS 26.0, *) {
          self.shellModel.presentWaterPicker(currentAmount: currentAmount)
        } else {
          self.showLegacyWaterPicker(currentAmount: currentAmount)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func showTabs() {
    guard
      nativeShellController == nil,
      let flutterViewController
    else {
      return
    }

    flutterViewController.view.backgroundColor = .systemBackground

    if #available(iOS 26.0, *) {
      let controller = UIHostingController(
        rootView: MensuraNativeTabShell(
          flutterViewController: flutterViewController,
          model: shellModel
        )
      )
      controller.view.backgroundColor = .systemBackground
      controller.overrideUserInterfaceStyle = .light
      nativeShellController = controller
      window?.rootViewController = controller
      window?.backgroundColor = .systemBackground
      window?.makeKeyAndVisible()
      return
    }

    let native = emptyTab(
      title: "Swift",
      symbol: "swift",
      selectedSymbol: "swift"
    )
    let activity = emptyTab(
      title: "Activity",
      symbol: "bell",
      selectedSymbol: "bell.fill"
    )
    let search = emptyTab(
      title: "Search",
      symbol: "magnifyingglass",
      selectedSymbol: "magnifyingglass"
    )

    let controller = UITabBarController()
    controller.view.backgroundColor = .systemBackground
    controller.viewControllers = [
      flutterViewController,
      native,
      activity,
      search,
    ]
    controller.selectedIndex = 0
    nativeShellController = controller
    window?.rootViewController = controller
    window?.makeKeyAndVisible()
  }

  private func showLegacyWaterPicker(currentAmount: Int) {
    guard let presenter = window?.rootViewController else { return }
    let alert = UIAlertController(
      title: "Add water",
      message: nil,
      preferredStyle: .actionSheet
    )
    for amount in [250, 330, 500, 750] {
      alert.addAction(
        UIAlertAction(title: "+\(amount) ml", style: .default) {
          [weak self] _ in
          self?.nativeChannel?.invokeMethod(
            "waterAmountSelected",
            arguments: amount
          )
        }
      )
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    presenter.present(alert, animated: true)
  }

  private func emptyTab(
    title: String,
    symbol: String,
    selectedSymbol: String
  ) -> UIViewController {
    let controller = UIViewController()
    controller.view.backgroundColor = .systemBackground
    controller.tabBarItem = UITabBarItem(
      title: title,
      image: UIImage(systemName: symbol),
      selectedImage: UIImage(systemName: selectedSymbol)
    )
    return controller
  }
}

@available(iOS 26.0, *)
private enum MensuraTab: Hashable {
  case home
  case swift
  case activity
  case search
}

@available(iOS 26.0, *)
private struct MensuraNativeTabShell: View {
  let flutterViewController: FlutterViewController
  @ObservedObject var model: MensuraShellModel

  @State private var selection = MensuraTab.home
  @State private var searchText = ""

  var body: some View {
    TabView(selection: $selection) {
      Tab("Home", systemImage: "house", value: MensuraTab.home) {
        FlutterControllerHost(controller: flutterViewController)
          .background(Color(uiColor: .systemBackground))
          .ignoresSafeArea(.container, edges: .top)
      }

      Tab("Swift", systemImage: "swift", value: MensuraTab.swift) {
        MensuraSwiftDashboard(model: model)
      }

      Tab("Activity", systemImage: "bell", value: MensuraTab.activity) {
        NativePlaceholder(
          title: "Activity",
          symbol: "bell.badge"
        )
      }

      Tab(value: MensuraTab.search, role: .search) {
        NativePlaceholder(
          title: "Search",
          symbol: "magnifyingglass"
        )
      }
    }
    .searchable(
      text: $searchText,
      isPresented: .constant(selection == .search),
      prompt: "Search"
    )
    .tabBarMinimizeBehavior(.onScrollDown)
    .tint(.black)
    .background(Color(uiColor: .systemBackground).ignoresSafeArea())
    .sheet(isPresented: $model.isWaterSheetPresented) {
      NativeWaterPicker(model: model)
        .presentationDetents([.height(390)])
        .presentationDragIndicator(.visible)
    }
  }
}

@available(iOS 26.0, *)
private struct FlutterControllerHost: UIViewControllerRepresentable {
  let controller: FlutterViewController

  func makeUIViewController(context: Context) -> FlutterViewController {
    controller.view.backgroundColor = .systemBackground
    return controller
  }

  func updateUIViewController(
    _ uiViewController: FlutterViewController,
    context: Context
  ) {
    uiViewController.view.backgroundColor = .systemBackground
  }
}

@available(iOS 26.0, *)
private struct NativePlaceholder: View {
  let title: String
  let symbol: String

  var body: some View {
    NavigationStack {
      ContentUnavailableView(title, systemImage: symbol)
        .navigationTitle(title)
    }
  }
}

@available(iOS 26.0, *)
private struct NativeWaterPicker: View {
  @ObservedObject var model: MensuraShellModel

  private let amounts = [200, 250, 330, 400, 500, 750, 1000]

  var body: some View {
    NavigationStack {
      VStack(spacing: 18) {
        Picker("Water amount", selection: $model.pendingWaterAmount) {
          ForEach(amounts, id: \.self) { amount in
            Text("\(amount) ml")
              .tag(amount)
          }
        }
        .pickerStyle(.wheel)

        Button {
          model.addWater()
        } label: {
          Text("Add \(model.pendingWaterAmount) ml")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
        .padding(.horizontal, 18)
      }
      .navigationTitle("Add water")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            model.isWaterSheetPresented = false
          }
        }
      }
    }
  }
}

@available(iOS 26.0, *)
private struct MensuraSwiftDashboard: View {
  @ObservedObject var model: MensuraShellModel

  @State private var editing = false
  @State private var showQuickLog = true
  @State private var waterMl = 1000
  @State private var extraCards = ["Steps"]

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        NativeNutritionPanel()

        VStack(alignment: .leading, spacing: 18) {
          if editing {
            editBanner
          }

          waterAndLog

          ForEach(extraCards, id: \.self) { card in
            if card == "Steps" {
              stepsCard
            } else {
              simpleCard(title: card)
            }
          }

          if editing {
            Button {
              if !extraCards.contains("Weight trend") {
                extraCards.append("Weight trend")
              } else if !extraCards.contains("Sleep") {
                extraCards.append("Sleep")
              }
            } label: {
              Label("Add card", systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(.bordered)
            .tint(.primary)
          }

          Color.clear.frame(height: 280)
        }
        .padding(.horizontal, 13)
        .padding(.top, 18)
      }
    }
    .scrollIndicators(.hidden)
    .background(
      Color(red: 248 / 255, green: 246 / 255, blue: 249 / 255)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 5) {
          UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
          withAnimation(.snappy) {
            editing = true
          }
        }
    )
    .environment(\.font, .system(.body, design: .default))
    .onChange(of: model.lastAddedWaterAmount) { _, amount in
      guard amount > 0 else { return }
      waterMl += amount
    }
  }

  private var editBanner: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text("Edit Dashboard")
          .font(.headline)
        Text("Move, hide, or add cards.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button("Done") {
        withAnimation(.snappy) {
          editing = false
        }
      }
      .fontWeight(.semibold)
    }
    .padding(14)
    .background(.background, in: RoundedRectangle(cornerRadius: 14))
  }

  private var waterAndLog: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Water & Log")
          .font(.system(size: 24, weight: .medium))
        Spacer()
        if editing {
          Button(showQuickLog ? "Hide log" : "Show log") {
            withAnimation(.snappy) {
              showQuickLog.toggle()
            }
          }
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        }
      }

      HStack(spacing: 14) {
        if showQuickLog {
          Color(uiColor: .systemBackground)
          .frame(maxWidth: .infinity, minHeight: 200)
          .background(
            Color(uiColor: .systemBackground),
            in: RoundedRectangle(cornerRadius: 8)
          )
          .shadow(color: .black.opacity(0.08), radius: 4)
        } else {
          Spacer(minLength: 0)
        }

        NativeWaterCard(
          waterMl: waterMl,
          expanded: !showQuickLog
        ) {
          model.pendingWaterAmount = 330
          model.isWaterSheetPresented = true
        }
        .frame(
          maxWidth: showQuickLog ? .infinity : 181,
          minHeight: 200
        )
      }
    }
  }

  private var stepsCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Steps")
        .font(.system(size: 24, weight: .medium))
      VStack(spacing: 2) {
        Text("0 Steps")
          .font(.system(size: 21, weight: .medium))
        Text("0 km | 0 cal")
          .font(.system(size: 16))
          .foregroundStyle(.secondary)
        Spacer()
        GeometryReader { proxy in
          ZStack(alignment: .leading) {
            Capsule().fill(Color(red: 243 / 255, green: 239 / 255, blue: 244 / 255))
            Capsule()
              .fill(Color(red: 151 / 255, green: 81 / 255, blue: 176 / 255))
              .frame(width: proxy.size.width * 0.66)
              .padding(2)
          }
        }
        .frame(height: 22)
      }
      .frame(height: 106)
      .padding(.horizontal, 7)
      .padding(.vertical, 4)
      .background(Color(uiColor: .systemBackground))
    }
  }

  private func simpleCard(title: String) -> some View {
    HStack {
      Image(systemName: title == "Sleep" ? "moon.fill" : "chart.bar.fill")
        .font(.title2)
        .frame(width: 44, height: 44)
        .background(.purple.opacity(0.12), in: Circle())
      VStack(alignment: .leading) {
        Text(title).font(.headline)
        Text(title == "Sleep" ? "7 h 42 m" : "70.0 kg")
          .font(.title3.weight(.semibold))
        Text(title == "Sleep" ? "Last night" : "No change this week")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if editing {
        Button(role: .destructive) {
          extraCards.removeAll { $0 == title }
        } label: {
          Image(systemName: "minus.circle.fill")
        }
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, minHeight: 126)
    .background(.background, in: RoundedRectangle(cornerRadius: 12))
  }
}

@available(iOS 26.0, *)
private struct NativeNutritionPanel: View {
  private let track = Color(red: 243 / 255, green: 239 / 255, blue: 244 / 255)

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Sunday, 25 AUGUST")
        .font(.system(size: 16))
        .foregroundStyle(.secondary)
      Text("Today")
        .font(.system(size: 29, weight: .semibold))
        .tracking(-0.7)

      HStack(spacing: 0) {
        calorieMetric("100", "Eat")

        ZStack {
          Circle()
            .trim(from: 0.10, to: 0.90)
            .stroke(
              track,
              style: StrokeStyle(lineWidth: 8, lineCap: .round)
            )
            .rotationEffect(.degrees(90))
          Circle()
            .trim(from: 0.10, to: 0.13)
            .stroke(
              Color(red: 92 / 255, green: 156 / 255, blue: 252 / 255),
              style: StrokeStyle(lineWidth: 8, lineCap: .round)
            )
            .rotationEffect(.degrees(90))
          VStack(spacing: 7) {
            Text("2600")
              .font(.system(size: 34))
              .tracking(-0.8)
            Text("Remaining")
              .font(.system(size: 16))
              .foregroundStyle(.secondary)
          }
        }
        .frame(width: 170, height: 170)

        calorieMetric("2900", "Target")
      }
      .frame(height: 176)
      .padding(.top, 22)

      HStack(spacing: 41) {
        macro("Protein", "54 / 120g", 0.60, Color(red: 1, green: 135 / 255, blue: 98 / 255))
        macro("Fat", "31 / 60g", 0.49, Color(red: 1, green: 197 / 255, blue: 70 / 255))
        macro("Carbs", "76 / 350g", 0.67, Color(red: 81 / 255, green: 176 / 255, blue: 125 / 255))
      }
      .padding(.top, 12)
    }
    .padding(.horizontal, 14)
    .padding(.top, 16)
    .padding(.bottom, 30)
    .background(Color(uiColor: .systemBackground))
  }

  private func calorieMetric(_ value: String, _ label: String) -> some View {
    VStack(spacing: 5) {
      Text(value)
        .font(.system(size: 22, weight: .medium))
      Text(label)
        .font(.system(size: 16))
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
  }

  private func macro(
    _ title: String,
    _ value: String,
    _ progress: CGFloat,
    _ color: Color
  ) -> some View {
    VStack(spacing: 6) {
      Text(title)
        .font(.system(size: 15))
        .foregroundStyle(.secondary)
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Rectangle().fill(track)
          Rectangle()
            .fill(color)
            .frame(width: proxy.size.width * progress)
        }
      }
      .frame(height: 7)
      Text(value)
        .font(.system(size: 14))
    }
    .frame(maxWidth: .infinity)
  }
}

@available(iOS 26.0, *)
private struct NativeWaterCard: View {
  let waterMl: Int
  let expanded: Bool
  let onAdd: () -> Void

  @State private var phase = 0.0

  var body: some View {
    GeometryReader { proxy in
      let gaugeWidth = expanded ? proxy.size.width * 0.45 : 30.0
      ZStack(alignment: .trailing) {
        HStack(spacing: 0) {
          VStack(spacing: 1) {
            Text("Water")
              .font(.system(size: 15, weight: .medium))
            Text("\(waterMl)ml")
              .font(.system(size: 19, weight: .medium))
            Spacer()
            Button("+330ml", action: onAdd)
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 29)
              .background(.blue, in: RoundedRectangle(cornerRadius: 12))
              .padding(.horizontal, 14)
              .padding(.bottom, 24)
          }
          .padding(.top, 5)
          .frame(width: proxy.size.width - gaugeWidth)

          ZStack {
            Color(red: 186 / 255, green: 217 / 255, blue: 254 / 255)
            WaterWaveShape(progress: min(Double(waterMl) / 1500, 1), phase: phase)
              .fill(Color(red: 1 / 255, green: 102 / 255, blue: 237 / 255))
            VStack {
              ForEach(0..<4, id: \.self) { _ in
                Capsule()
                  .fill(.blue.opacity(0.24))
                  .frame(width: gaugeWidth * 0.32, height: 2)
                Spacer()
              }
            }
            .padding(.vertical, 30)
          }
          .frame(width: gaugeWidth)
        }
      }
      .background(Color(uiColor: .systemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .shadow(color: .black.opacity(0.08), radius: 4)
      .onLongPressGesture(perform: onAdd)
      .onAppear {
        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
          phase = .pi * 2
        }
      }
    }
  }
}

@available(iOS 26.0, *)
private struct WaterWaveShape: Shape {
  var progress: Double
  var phase: Double

  var animatableData: Double {
    get { phase }
    set { phase = newValue }
  }

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let top = rect.height * (1 - progress)
    path.move(to: CGPoint(x: 0, y: top))
    for x in stride(from: 0.0, through: rect.width, by: 1.0) {
      let y = top + sin((x / rect.width) * .pi * 2 + phase) * 2
      path.addLine(to: CGPoint(x: x, y: y))
    }
    path.addLine(to: CGPoint(x: rect.width, y: rect.height))
    path.addLine(to: CGPoint(x: 0, y: rect.height))
    path.closeSubpath()
    return path
  }
}

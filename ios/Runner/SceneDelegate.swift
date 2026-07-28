import Flutter
import SwiftUI
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private weak var flutterViewController: FlutterViewController?
  private var nativeShellController: UIViewController?

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

    flutterViewController.tabBarItem = UITabBarItem(
      title: "Home",
      image: UIImage(systemName: "house"),
      selectedImage: UIImage(systemName: "house.fill")
    )

    let channel = FlutterMethodChannel(
      name: "com.mensura/native_shell",
      binaryMessenger: flutterViewController.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "showTabs" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.showTabs()
      result(nil)
    }
  }

  private func showTabs() {
    guard
      nativeShellController == nil,
      let flutterViewController
    else {
      return
    }

    if #available(iOS 26.0, *) {
      let controller = UIHostingController(
        rootView: MensuraNativeTabShell(
          flutterViewController: flutterViewController
        )
      )
      nativeShellController = controller
      window?.rootViewController = controller
      window?.makeKeyAndVisible()
      return
    }

    let diary = emptyTab(
      title: "Library",
      symbol: "tray",
      selectedSymbol: "tray.fill"
    )
    let messages = emptyTab(
      title: "Messages",
      symbol: "message",
      selectedSymbol: "message.fill"
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
    controller.viewControllers = [
      flutterViewController,
      diary,
      messages,
      activity,
      search,
    ]
    controller.selectedIndex = 0
    nativeShellController = controller
    window?.rootViewController = controller
    window?.makeKeyAndVisible()
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
  case library
  case messages
  case activity
  case search
}

@available(iOS 26.0, *)
private struct MensuraNativeTabShell: View {
  let flutterViewController: FlutterViewController

  @State private var selection = MensuraTab.home
  @State private var searchText = ""

  var body: some View {
    TabView(selection: $selection) {
      Tab("Home", systemImage: "house", value: MensuraTab.home) {
        FlutterControllerHost(controller: flutterViewController)
      }

      Tab("Library", systemImage: "tray", value: MensuraTab.library) {
        Color(uiColor: .systemBackground)
      }

      Tab("Messages", systemImage: "message", value: MensuraTab.messages) {
        Color(uiColor: .systemBackground)
      }

      Tab("Activity", systemImage: "bell", value: MensuraTab.activity) {
        Color(uiColor: .systemBackground)
      }

      Tab(value: MensuraTab.search, role: .search) {
        Color(uiColor: .systemBackground)
      }
    }
    .searchable(text: $searchText, prompt: "Search")
    .tabBarMinimizeBehavior(.onScrollDown)
    .tint(.black)
  }
}

@available(iOS 26.0, *)
private struct FlutterControllerHost: UIViewControllerRepresentable {
  let controller: FlutterViewController

  func makeUIViewController(context: Context) -> FlutterViewController {
    controller
  }

  func updateUIViewController(
    _ uiViewController: FlutterViewController,
    context: Context
  ) {}
}

param(
  [ValidateSet('home', 'measurements', 'login', 'age')]
  [string]$Screen = 'home'
)

$env:MENSURA_PREVIEW_SCREEN = $Screen
flutter run -d windows

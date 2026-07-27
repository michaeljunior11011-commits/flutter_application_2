import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: const Color(0x00000000),
      systemNavigationBarColor: CupertinoColors.white,
    ),
  );
  runApp(const MensuraApp());
}

class MensuraApp extends StatelessWidget {
  const MensuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'MENSURA',
      builder: _appBuilder,
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.black,
        scaffoldBackgroundColor: CupertinoColors.white,
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            color: Color(0xFF090909),
            fontSize: 17,
            letterSpacing: -0.2,
          ),
        ),
      ),
      home: LandingPage(),
    );
  }
}

Widget _appBuilder(BuildContext context, Widget? child) {
  return MouseRegion(
    cursor: SystemMouseCursors.basic,
    child: child ?? const SizedBox.shrink(),
  );
}

class OnboardingData {
  DateTime birthday = DateTime(DateTime.now().year - 18, 1, 1);
  String? gender;
  String heightUnit = 'ft';
  double? heightCm;
  String weightUnit = 'kg';
  double? weightKg;
  String? goal;
  String? pace;
  String? movement;
  String steps = 'unknown';
  double? frequency;
  final Set<String> training = {};
  double? duration;
  double? bodyFat;
  bool? knowsBodyFat;
  String targetWeightUnit = 'kg';
  double? targetWeightKg;

  int get age {
    final now = DateTime.now();
    var years = now.year - birthday.year;
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      years--;
    }
    return years;
  }
}

const _black = Color(0xFF090909);
const _secondary = Color(0xFF66666D);
const _soft = Color(0xFFF6F6F7);
const _track = Color(0xFFE3E3E7);
const _line = Color(0xFFD0D2D6);
const _error = Color(0xFFC62828);

void _tapHaptic() => HapticFeedback.lightImpact();
void _selectionHaptic() => HapticFeedback.selectionClick();

Future<void> _push(BuildContext context, Widget page) {
  _tapHaptic();
  return Navigator.of(
    context,
  ).push(CupertinoPageRoute<void>(builder: (_) => page));
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = OnboardingData();
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            return Stack(
              children: [
                Positioned(
                  top: 13,
                  left: 0,
                  right: 0,
                  child: _Entrance(
                    controller: _controller,
                    interval: const Interval(
                      0,
                      .55,
                      curve: Curves.easeOutCubic,
                    ),
                    offset: const Offset(0, -.08),
                    child: const Text(
                      'MENSURA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _black,
                        fontSize: 40,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -1.2,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: math.max(410, height * .72),
                  child: Column(
                    children: [
                      _Entrance(
                        controller: _controller,
                        interval: const Interval(
                          .18,
                          .75,
                          curve: Curves.easeOutCubic,
                        ),
                        child: const Text(
                          'Your Nutrition, Clearly Measured.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF68686D),
                            fontSize: 18.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 38),
                      _Entrance(
                        controller: _controller,
                        interval: const Interval(
                          .32,
                          1,
                          curve: Curves.easeOutCubic,
                        ),
                        offset: const Offset(0, .16),
                        child: _PrimaryButton(
                          label: 'Get Started',
                          onPressed: () => _push(context, AgePage(data: data)),
                        ),
                      ),
                      const SizedBox(height: 9),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 11,
                        ),
                        onPressed: () => _push(context, const LoginPage()),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            color: _black,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.controller,
    required this.interval,
    required this.child,
    this.offset = const Offset(0, .08),
  });

  final AnimationController controller;
  final Interval interval;
  final Widget child;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(parent: controller, curve: interval);
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: offset,
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

class _OnboardingScaffold extends StatelessWidget {
  const _OnboardingScaffold({
    required this.title,
    required this.child,
    required this.buttonLabel,
    required this.onContinue,
    this.step,
  });

  final String title;
  final Widget child;
  final String buttonLabel;
  final VoidCallback onContinue;
  final int? step;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      resizeToAvoidBottomInset: true,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (step != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
                child: _ProgressBar(step: step!),
              ),
            SizedBox(height: step == null ? 5 : 7),
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: CupertinoButton(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.only(left: 18, right: 8),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: CustomPaint(painter: _BackArrowPainter()),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _black,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.55,
                      ),
                    ),
                  ),
                  const SizedBox(width: 64),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                child: child,
              ),
            ),
            AnimatedPadding(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.fromLTRB(22, 8, 22, keyboard > 0 ? 12 : 42),
              child: _PrimaryButton(label: buttonLabel, onPressed: onContinue),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(13, (index) {
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            height: 5,
            margin: EdgeInsets.only(right: index == 12 ? 0 : 4),
            decoration: BoxDecoration(
              color: index < step ? CupertinoColors.black : _track,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      }),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        _tapHaptic();
        widget.onPressed();
      },
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedScale(
              scale: _pressed ? .992 : 1,
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: _pressed ? .72 : 1,
                duration: const Duration(milliseconds: 110),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: CupertinoColors.black,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24000000),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeetInchesField extends StatefulWidget {
  const _FeetInchesField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  State<_FeetInchesField> createState() => _FeetInchesFieldState();
}

class _FeetInchesFieldState extends State<_FeetInchesField> {
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    focusNode.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    focusNode
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text;
    final feet = value.isEmpty ? '' : value.substring(0, 1);
    final inches = value.length < 2 ? '' : value.substring(1);
    final activeSecond = value.isNotEmpty;
    return SizedBox(
      width: 238,
      height: 66,
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MeasurementSlot(
                value: feet,
                placeholder: '5',
                focused: focusNode.hasFocus && !activeSecond,
              ),
              const SizedBox(width: 30),
              _MeasurementSlot(
                value: inches,
                placeholder: '7',
                focused: focusNode.hasFocus && activeSecond,
              ),
            ],
          ),
          Positioned.fill(
            child: CupertinoTextField(
              controller: widget.controller,
              focusNode: focusNode,
              maxLength: 3,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              cursorColor: const Color(0x00000000),
              style: const TextStyle(color: Color(0x00000000), fontSize: 1),
              decoration: const BoxDecoration(color: Color(0x00000000)),
              onChanged: (value) {
                widget.onChanged(value);
                setState(() {});
              },
              onSubmitted: (_) => widget.onSubmitted(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasurementSlot extends StatelessWidget {
  const _MeasurementSlot({
    required this.value,
    required this.placeholder,
    required this.focused,
  });

  final String value;
  final String placeholder;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 104,
      height: 64,
      alignment: Alignment.center,
      padding: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: focused ? _black : _line, width: 3),
        ),
      ),
      child: Text(
        value.isEmpty ? placeholder : value,
        style: TextStyle(
          color: value.isEmpty ? const Color(0xFFB1B2B7) : _black,
          fontSize: 44,
          height: 1.15,
          fontWeight: value.isEmpty ? FontWeight.w400 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.long = false});
  final String text;
  final bool long;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: _black,
        fontSize: long ? 30 : 36,
        height: long ? 1.16 : 1.12,
        fontWeight: FontWeight.w700,
        letterSpacing: long ? -1.14 : -1.62,
      ),
    );
  }
}

class _Description extends StatelessWidget {
  const _Description(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 11),
      child: Text(
        text,
        style: const TextStyle(
          color: _secondary,
          fontSize: 18,
          height: 1.5,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text, {required this.visible});
  final String text;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: visible
          ? Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _error,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _ChoiceCard extends StatefulWidget {
  const _ChoiceCard({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.centered = false,
  });

  final String title;
  final String? subtitle;
  final Widget? icon;
  final bool selected;
  final bool centered;
  final VoidCallback onTap;

  @override
  State<_ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<_ChoiceCard> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => pressed = true),
      onTapCancel: () => setState(() => pressed = false),
      onTapUp: (_) => setState(() => pressed = false),
      onTap: () {
        _selectionHaptic();
        widget.onTap();
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: pressed ? .72 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          constraints: BoxConstraints(minHeight: widget.centered ? 58 : 62),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
          decoration: BoxDecoration(
            color: _soft,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: widget.selected ? CupertinoColors.black : _soft,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: widget.centered
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              if (widget.icon != null) ...[
                SizedBox(width: 22, height: 22, child: widget.icon),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: widget.centered
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      textAlign: widget.centered
                          ? TextAlign.center
                          : TextAlign.left,
                      style: TextStyle(
                        color: _black,
                        fontSize: 17,
                        height: 1.3,
                        fontWeight: widget.centered
                            ? FontWeight.w500
                            : FontWeight.w600,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle!,
                        style: const TextStyle(
                          color: Color(0xFF707077),
                          fontSize: 14,
                          height: 1.42,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Options extends StatelessWidget {
  const _Options({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class AgePage extends StatefulWidget {
  const AgePage({super.key, required this.data});
  final OnboardingData data;

  @override
  State<AgePage> createState() => _AgePageState();
}

class _AgePageState extends State<AgePage> {
  bool error = false;

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      step: 1,
      title: 'Age',
      buttonLabel: 'Continue',
      onContinue: () {
        final valid = widget.data.age >= 16 && widget.data.age <= 80;
        setState(() => error = !valid);
        if (valid) _push(context, GenderPage(data: widget.data));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading('How old are you?'),
          const _Description('Select your date of birth.'),
          const SizedBox(height: 26),
          SizedBox(
            height: 180,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: widget.data.birthday,
              minimumDate: DateTime(DateTime.now().year - 80),
              maximumDate: DateTime(DateTime.now().year - 16),
              onDateTimeChanged: (value) {
                widget.data.birthday = value;
                setState(() => error = false);
              },
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${widget.data.age} years old',
              style: const TextStyle(color: Color(0xFF85858B), fontSize: 14),
            ),
          ),
          _ErrorText(
            'This calculator currently supports users age 16 and older.',
            visible: error,
          ),
        ],
      ),
    );
  }
}

class GenderPage extends StatefulWidget {
  const GenderPage({super.key, required this.data});
  final OnboardingData data;

  @override
  State<GenderPage> createState() => _GenderPageState();
}

class _GenderPageState extends State<GenderPage> {
  bool error = false;

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      step: 2,
      title: 'Gender',
      buttonLabel: 'Continue',
      onContinue: () {
        setState(() => error = widget.data.gender == null);
        if (!error) _push(context, HeightPage(data: widget.data));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading(
            'Which option should we use for your calorie calculation?',
            long: true,
          ),
          const _Description(
            'This is used only to estimate your energy needs.',
          ),
          _Options(
            children: [
              _ChoiceCard(
                title: 'Male',
                icon: const CustomPaint(
                  painter: _GenderIconPainter(male: true),
                ),
                selected: widget.data.gender == 'male',
                onTap: () => setState(() {
                  widget.data.gender = 'male';
                  error = false;
                }),
              ),
              _ChoiceCard(
                title: 'Female',
                icon: const CustomPaint(
                  painter: _GenderIconPainter(male: false),
                ),
                selected: widget.data.gender == 'female',
                onTap: () => setState(() {
                  widget.data.gender = 'female';
                  error = false;
                }),
              ),
            ],
          ),
          _ErrorText('Please choose an option.', visible: error),
        ],
      ),
    );
  }
}

class _UnderlineField extends StatelessWidget {
  const _UnderlineField({
    required this.controller,
    required this.placeholder,
    this.maxLength = 3,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String placeholder;
  final int maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        maxLength: maxLength,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        textInputAction: TextInputAction.next,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 9),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _line, width: 3)),
        ),
        placeholderStyle: const TextStyle(
          color: Color(0xFFB1B2B7),
          fontSize: 44,
          fontWeight: FontWeight.w400,
        ),
        style: const TextStyle(
          color: _black,
          fontSize: 44,
          height: 1.2,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  final List<String> values;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < values.length; i++) ...[
          GestureDetector(
            onTap: () {
              _selectionHaptic();
              onChanged(values[i]);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              width: values[i] == 'ft / in' ? 82 : 70,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: selected == values[i] ? _black : _soft,
                  width: 2,
                ),
              ),
              child: Text(
                values[i],
                style: const TextStyle(
                  color: _black,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (i != values.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class HeightPage extends StatefulWidget {
  const HeightPage({super.key, required this.data});
  final OnboardingData data;

  @override
  State<HeightPage> createState() => _HeightPageState();
}

class _HeightPageState extends State<HeightPage> {
  final primary = TextEditingController();
  final feetCombined = TextEditingController();
  bool error = false;

  @override
  void dispose() {
    primary.dispose();
    feetCombined.dispose();
    super.dispose();
  }

  void setUnit(String value) {
    setState(() {
      widget.data.heightUnit = value == 'cm' ? 'cm' : 'ft';
      primary.clear();
      feetCombined.clear();
      error = false;
    });
  }

  void submit() {
    var valid = false;
    if (widget.data.heightUnit == 'cm') {
      final cm = double.tryParse(primary.text);
      valid = cm != null && cm >= 100 && cm <= 250;
      if (valid) widget.data.heightCm = cm;
    } else {
      final value = feetCombined.text;
      final ft = value.isEmpty ? null : int.tryParse(value.substring(0, 1));
      final inch = value.length < 2 ? null : int.tryParse(value.substring(1));
      valid =
          ft != null &&
          inch != null &&
          ft >= 3 &&
          ft <= 8 &&
          inch >= 0 &&
          inch <= 11;
      if (valid) widget.data.heightCm = (ft * 12 + inch) * 2.54;
    }
    setState(() => error = !valid);
    if (valid) _push(context, WeightPage(data: widget.data));
  }

  @override
  Widget build(BuildContext context) {
    final cm = widget.data.heightUnit == 'cm';
    return _OnboardingScaffold(
      step: 3,
      title: 'Height',
      buttonLabel: 'Continue',
      onContinue: submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading('What’s your height?'),
          const _Description(
            'Your height helps us estimate your energy needs.',
          ),
          const SizedBox(height: 42),
          Center(
            child: cm
                ? _UnderlineField(
                    controller: primary,
                    placeholder: '170',
                    maxLength: 3,
                    onChanged: (_) => setState(() => error = false),
                    onSubmitted: (_) => submit(),
                  )
                : _FeetInchesField(
                    controller: feetCombined,
                    onChanged: (_) => setState(() => error = false),
                    onSubmitted: submit,
                  ),
          ),
          _ErrorText('Please enter a valid height.', visible: error),
          const SizedBox(height: 16),
          _UnitToggle(
            values: const ['cm', 'ft / in'],
            selected: cm ? 'cm' : 'ft / in',
            onChanged: setUnit,
          ),
        ],
      ),
    );
  }
}

class WeightPage extends StatefulWidget {
  const WeightPage({super.key, required this.data});
  final OnboardingData data;

  @override
  State<WeightPage> createState() => _WeightPageState();
}

class _WeightPageState extends State<WeightPage> {
  final controller = TextEditingController();
  bool error = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    final value = double.tryParse(controller.text);
    final kg = widget.data.weightUnit == 'kg'
        ? value
        : value == null
        ? null
        : value / 2.2046226218;
    final valid = kg != null && kg >= 30 && kg <= 400;
    setState(() => error = !valid);
    if (valid) {
      widget.data.weightKg = kg;
      _push(context, GoalPage(data: widget.data));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      step: 4,
      title: 'Weight',
      buttonLabel: 'Continue',
      onContinue: submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading('What’s your current weight?'),
          const _Description(
            'Your current weight is used to estimate your daily energy needs.',
          ),
          const SizedBox(height: 42),
          Center(
            child: _UnderlineField(
              controller: controller,
              placeholder: widget.data.weightUnit == 'kg' ? '70' : '154',
              onChanged: (_) => setState(() => error = false),
              onSubmitted: (_) => submit(),
            ),
          ),
          _ErrorText('Please enter a valid weight.', visible: error),
          const SizedBox(height: 16),
          _UnitToggle(
            values: const ['kg', 'lb'],
            selected: widget.data.weightUnit,
            onChanged: (value) => setState(() {
              widget.data.weightUnit = value;
              controller.clear();
              error = false;
            }),
          ),
        ],
      ),
    );
  }
}

class GoalPage extends StatefulWidget {
  const GoalPage({super.key, required this.data});
  final OnboardingData data;

  @override
  State<GoalPage> createState() => _GoalPageState();
}

class _GoalPageState extends State<GoalPage> {
  bool error = false;

  @override
  Widget build(BuildContext context) {
    const options = {
      'lose': 'Lose fat',
      'maintain': 'Maintain weight',
      'build': 'Build muscle',
      'performance': 'Improve performance',
    };
    return _OnboardingScaffold(
      step: 5,
      title: 'Goal',
      buttonLabel: 'Continue',
      onContinue: () {
        setState(() => error = widget.data.goal == null);
        if (error) return;
        if (widget.data.goal == 'lose' || widget.data.goal == 'build') {
          _push(context, PacePage(data: widget.data));
        } else {
          _push(context, MovementPage(data: widget.data, step: 6));
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading('What’s your main goal?'),
          _Options(
            children: options.entries
                .map(
                  (entry) => _ChoiceCard(
                    title: entry.value,
                    centered: true,
                    selected: widget.data.goal == entry.key,
                    onTap: () => setState(() {
                      widget.data.goal = entry.key;
                      error = false;
                    }),
                  ),
                )
                .toList(),
          ),
          _ErrorText('Please choose your main goal.', visible: error),
        ],
      ),
    );
  }
}

class PacePage extends StatefulWidget {
  const PacePage({super.key, required this.data});
  final OnboardingData data;

  @override
  State<PacePage> createState() => _PacePageState();
}

class _PacePageState extends State<PacePage> {
  bool error = false;

  @override
  Widget build(BuildContext context) {
    final losing = widget.data.goal == 'lose';
    final options = losing
        ? const [
            ('gentle', 'Gentle', 'Easier to maintain · 10% deficit'),
            ('recommended', 'Recommended', 'Balanced progress · 15% deficit'),
            ('fast', 'Fast', 'More demanding · 20% deficit'),
          ]
        : const [
            ('lean', 'Lean gain', 'Smaller surplus · 5%'),
            ('standard', 'Standard gain', 'Moderate surplus · 10%'),
          ];
    return _OnboardingScaffold(
      step: 6,
      title: 'Progress',
      buttonLabel: 'Continue',
      onContinue: () {
        setState(() => error = widget.data.pace == null);
        if (!error) _push(context, MovementPage(data: widget.data, step: 7));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading('How fast would you like to progress?'),
          _Options(
            children: options
                .map(
                  (entry) => _ChoiceCard(
                    title: entry.$2,
                    subtitle: entry.$3,
                    selected: widget.data.pace == entry.$1,
                    onTap: () => setState(() {
                      widget.data.pace = entry.$1;
                      error = false;
                    }),
                  ),
                )
                .toList(),
          ),
          _ErrorText('Please choose a pace.', visible: error),
        ],
      ),
    );
  }
}

class MovementPage extends StatefulWidget {
  const MovementPage({super.key, required this.data, required this.step});
  final OnboardingData data;
  final int step;

  @override
  State<MovementPage> createState() => _MovementPageState();
}

class _MovementPageState extends State<MovementPage> {
  bool error = false;

  @override
  Widget build(BuildContext context) {
    const options = [
      ('seated', 'Mostly seated', 'Desk work, studying, little walking'),
      ('some', 'Some walking', 'I move around occasionally'),
      ('feet', 'On my feet', 'I stand or walk for much of the day'),
      ('demanding', 'Physically demanding', 'Manual work or constant movement'),
    ];
    return _OnboardingScaffold(
      step: widget.step,
      title: 'Daily movement',
      buttonLabel: 'Continue',
      onContinue: () {
        setState(() => error = widget.data.movement == null);
        if (!error) {
          _push(context, StepsPage(data: widget.data, step: widget.step + 1));
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading(
            'Outside of exercise, what does a typical day look like?',
            long: true,
          ),
          _Options(
            children: options
                .map(
                  (entry) => _ChoiceCard(
                    title: entry.$2,
                    subtitle: entry.$3,
                    selected: widget.data.movement == entry.$1,
                    onTap: () => setState(() {
                      widget.data.movement = entry.$1;
                      error = false;
                    }),
                  ),
                )
                .toList(),
          ),
          _ErrorText('Please choose the closest option.', visible: error),
        ],
      ),
    );
  }
}

class StepsPage extends StatefulWidget {
  const StepsPage({super.key, required this.data, required this.step});
  final OnboardingData data;
  final int step;

  @override
  State<StepsPage> createState() => _StepsPageState();
}

class _StepsPageState extends State<StepsPage> {
  @override
  Widget build(BuildContext context) {
    const options = {
      'under3': 'Under 3,000',
      '3to6': '3,000–6,000',
      '6to10': '6,000–10,000',
      'over10': 'More than 10,000',
      'unknown': 'I’m not sure',
    };
    return _OnboardingScaffold(
      step: widget.step,
      title: 'Daily steps',
      buttonLabel: 'Continue',
      onContinue: () => _push(
        context,
        FrequencyPage(data: widget.data, step: widget.step + 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading('About how many steps do you take daily?'),
          const _Description('Optional, but it can improve the estimate.'),
          _Options(
            children: options.entries
                .map(
                  (entry) => _ChoiceCard(
                    title: entry.value,
                    centered: true,
                    selected: widget.data.steps == entry.key,
                    onTap: () => setState(() => widget.data.steps = entry.key),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class FrequencyPage extends StatefulWidget {
  const FrequencyPage({super.key, required this.data, required this.step});
  final OnboardingData data;
  final int step;

  @override
  State<FrequencyPage> createState() => _FrequencyPageState();
}

class _FrequencyPageState extends State<FrequencyPage> {
  bool error = false;

  @override
  Widget build(BuildContext context) {
    const options = [
      (0.0, 'I don’t currently exercise'),
      (1.5, '1–2 days per week'),
      (3.5, '3–4 days per week'),
      (5.5, '5–6 days per week'),
      (7.0, 'Every day'),
    ];
    return _OnboardingScaffold(
      step: widget.step,
      title: 'Exercise',
      buttonLabel: 'Continue',
      onContinue: () {
        setState(() => error = widget.data.frequency == null);
        if (!error) {
          _push(
            context,
            TrainingPage(data: widget.data, step: widget.step + 1),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading('How often do you exercise?'),
          _Options(
            children: options
                .map(
                  (entry) => _ChoiceCard(
                    title: entry.$2,
                    centered: true,
                    selected: widget.data.frequency == entry.$1,
                    onTap: () => setState(() {
                      widget.data.frequency = entry.$1;
                      if (entry.$1 == 0) widget.data.training.clear();
                      error = false;
                    }),
                  ),
                )
                .toList(),
          ),
          _ErrorText('Please choose an option.', visible: error),
        ],
      ),
    );
  }
}

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key, required this.data, required this.step});
  final OnboardingData data;
  final int step;

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  bool error = false;

  @override
  Widget build(BuildContext context) {
    const options = {
      'strength': 'Strength training',
      'cardio': 'Cardio',
      'sports': 'Sports',
      'walking': 'Walking',
      'mixed': 'Mixed training',
    };
    return _OnboardingScaffold(
      step: widget.step,
      title: 'Training',
      buttonLabel: 'Continue',
      onContinue: () {
        final valid =
            widget.data.frequency == 0 || widget.data.training.isNotEmpty;
        setState(() => error = !valid);
        if (valid) {
          _push(
            context,
            DurationPage(data: widget.data, step: widget.step + 1),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading('What type of training do you usually do?'),
          const _Description('Choose all that apply.'),
          Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: options.entries.map((entry) {
                final selected = widget.data.training.contains(entry.key);
                return GestureDetector(
                  onTap: () {
                    _selectionHaptic();
                    setState(() {
                      selected
                          ? widget.data.training.remove(entry.key)
                          : widget.data.training.add(entry.key);
                      error = false;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 170),
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? _black : _soft,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        color: _black,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          _ErrorText(
            'Choose at least one type, or continue if you don’t exercise.',
            visible: error,
          ),
        ],
      ),
    );
  }
}

class DurationPage extends StatefulWidget {
  const DurationPage({super.key, required this.data, required this.step});
  final OnboardingData data;
  final int step;

  @override
  State<DurationPage> createState() => _DurationPageState();
}

class _DurationPageState extends State<DurationPage> {
  bool error = false;

  @override
  Widget build(BuildContext context) {
    const options = [
      (22.5, 'Under 30 minutes'),
      (45.0, '30–60 minutes'),
      (75.0, '60–90 minutes'),
      (105.0, 'More than 90 minutes'),
    ];
    return _OnboardingScaffold(
      step: widget.step,
      title: 'Workout duration',
      buttonLabel: 'Continue',
      onContinue: () {
        final valid =
            widget.data.frequency == 0 || widget.data.duration != null;
        setState(() => error = !valid);
        if (valid) {
          if (widget.data.frequency == 0) widget.data.duration = 0;
          _push(context, BodyFatPage(data: widget.data, step: widget.step + 1));
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading('How long is a typical workout?'),
          _Options(
            children: options
                .map(
                  (entry) => _ChoiceCard(
                    title: entry.$2,
                    centered: true,
                    selected: widget.data.duration == entry.$1,
                    onTap: () => setState(() {
                      widget.data.duration = entry.$1;
                      error = false;
                    }),
                  ),
                )
                .toList(),
          ),
          _ErrorText('Please choose a typical duration.', visible: error),
        ],
      ),
    );
  }
}

class BodyFatPage extends StatefulWidget {
  const BodyFatPage({super.key, required this.data, required this.step});
  final OnboardingData data;
  final int step;

  @override
  State<BodyFatPage> createState() => _BodyFatPageState();
}

class _BodyFatPageState extends State<BodyFatPage> {
  final controller = TextEditingController();
  bool error = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    var valid = widget.data.knowsBodyFat != null;
    if (widget.data.knowsBodyFat == true) {
      final value = double.tryParse(controller.text);
      valid = value != null && value >= 3 && value <= 65;
      if (valid) widget.data.bodyFat = value;
    } else {
      widget.data.bodyFat = null;
    }
    setState(() => error = !valid);
    if (!valid) return;
    if (widget.data.goal == 'lose' || widget.data.goal == 'build') {
      _push(
        context,
        TargetPage(data: widget.data, step: math.min(13, widget.step + 1)),
      );
    } else {
      _push(context, SignupPage(data: widget.data));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      step: widget.step,
      title: 'Body fat',
      buttonLabel: 'Continue',
      onContinue: submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading('Do you know your body fat percentage?'),
          _Options(
            children: [
              _ChoiceCard(
                title: 'Yes',
                centered: true,
                selected: widget.data.knowsBodyFat == true,
                onTap: () => setState(() {
                  widget.data.knowsBodyFat = true;
                  error = false;
                }),
              ),
              _ChoiceCard(
                title: 'No',
                centered: true,
                selected: widget.data.knowsBodyFat == false,
                onTap: () => setState(() {
                  widget.data.knowsBodyFat = false;
                  controller.clear();
                  error = false;
                }),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: widget.data.knowsBodyFat == true
                ? Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: Center(
                      child: _UnderlineField(
                        controller: controller,
                        placeholder: '18',
                        maxLength: 2,
                        onChanged: (_) => setState(() => error = false),
                        onSubmitted: (_) => submit(),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          _ErrorText('Please complete this step.', visible: error),
        ],
      ),
    );
  }
}

class TargetPage extends StatefulWidget {
  const TargetPage({super.key, required this.data, required this.step});
  final OnboardingData data;
  final int step;

  @override
  State<TargetPage> createState() => _TargetPageState();
}

class _TargetPageState extends State<TargetPage> {
  final controller = TextEditingController();
  bool error = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  double? get targetKg {
    final value = double.tryParse(controller.text);
    if (value == null) return null;
    return widget.data.targetWeightUnit == 'kg' ? value : value / 2.2046226218;
  }

  bool get showWarning {
    final kg = targetKg;
    final cm = widget.data.heightCm;
    final current = widget.data.weightKg;
    if (kg == null || cm == null || current == null) return false;
    final bmi = kg / math.pow(cm / 100, 2);
    final change = (kg - current).abs() / current;
    return bmi < 18.5 || bmi >= 35 || change > .3;
  }

  void submit() {
    final kg = targetKg;
    final valid = kg != null && kg >= 30 && kg <= 400;
    setState(() => error = !valid);
    if (valid) {
      widget.data.targetWeightKg = kg;
      _push(context, SignupPage(data: widget.data));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      step: widget.step,
      title: 'Target weight',
      buttonLabel: 'Continue',
      onContinue: submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading('What weight are you aiming for?'),
          const _Description('You can adjust this later.'),
          const SizedBox(height: 42),
          Center(
            child: _UnderlineField(
              controller: controller,
              placeholder: widget.data.targetWeightUnit == 'kg' ? '65' : '143',
              onChanged: (_) => setState(() => error = false),
              onSubmitted: (_) => submit(),
            ),
          ),
          _ErrorText('Please enter a valid target weight.', visible: error),
          const SizedBox(height: 16),
          _UnitToggle(
            values: const ['kg', 'lb'],
            selected: widget.data.targetWeightUnit,
            onChanged: (value) => setState(() {
              widget.data.targetWeightUnit = value;
              controller.clear();
              error = false;
            }),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: showWarning
                ? Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7E6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'This target may be outside a typical range for your height or far from your current weight. You can continue, but consider reviewing it with a qualified professional.',
                      style: TextStyle(
                        color: Color(0xFF7B5100),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.label,
    required this.controller,
    required this.placeholder,
    this.obscure = false,
    this.keyboardType,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String placeholder;
  final bool obscure;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _black,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 58,
          child: CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            obscureText: obscure,
            keyboardType: keyboardType,
            onSubmitted: onSubmitted,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            style: const TextStyle(color: _black, fontSize: 17),
            placeholderStyle: const TextStyle(
              color: Color(0xFF9A9AA0),
              fontSize: 17,
            ),
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              border: Border.all(color: const Color(0xFFC7C8CD), width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}

class SignupPage extends StatefulWidget {
  const SignupPage({super.key, required this.data});
  final OnboardingData data;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void submit() {
    final mail = email.text.trim();
    final validEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(mail);
    setState(() {
      error = !validEmail
          ? 'Please enter a valid email address.'
          : password.text.length < 8
          ? 'Password must be at least 8 characters.'
          : null;
    });
    if (error == null) {
      _tapHaptic();
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      title: 'Create account',
      buttonLabel: 'Create account',
      onContinue: submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading('Save your plan'),
          const _Description(
            'Create an account to keep your calorie target and preferences.',
          ),
          const SizedBox(height: 30),
          _AuthField(
            label: 'Email',
            controller: email,
            placeholder: 'Enter your email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 15),
          _AuthField(
            label: 'Password',
            controller: password,
            placeholder: 'Create a password',
            obscure: true,
            onSubmitted: (_) => submit(),
          ),
          _ErrorText(error ?? '', visible: error != null),
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void submit() {
    _tapHaptic();
    if (email.text.trim().isNotEmpty && password.text.isNotEmpty) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      title: 'Login',
      buttonLabel: 'Login',
      onContinue: submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading('Welcome back'),
          const _Description('Log in to continue to your nutrition plan.'),
          const SizedBox(height: 30),
          _AuthField(
            label: 'Email',
            controller: email,
            placeholder: 'Enter your email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 15),
          _AuthField(
            label: 'Password',
            controller: password,
            placeholder: 'Enter your password',
            obscure: true,
            onSubmitted: (_) => submit(),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(
                child: SizedBox(
                  height: 1,
                  child: ColoredBox(color: Color(0xFFE0E0E3)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or',
                  style: TextStyle(
                    color: CupertinoColors.systemGrey.resolveFrom(context),
                    fontSize: 14,
                  ),
                ),
              ),
              const Expanded(
                child: SizedBox(
                  height: 1,
                  child: ColoredBox(color: Color(0xFFE0E0E3)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SocialButton(
                painter: const _GoogleLogoPainter(),
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 16),
              _SocialButton(
                painter: const _AppleLogoPainter(),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.onTap, required this.painter});

  final VoidCallback onTap;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: const Size(56, 56),
      padding: EdgeInsets.zero,
      onPressed: () {
        _tapHaptic();
        onTap();
      },
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          border: Border.all(color: const Color(0xFFDEDEE2), width: 1),
          borderRadius: BorderRadius.circular(28),
        ),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(painter: painter),
        ),
      ),
    );
  }
}

class _BackArrowPainter extends CustomPainter {
  const _BackArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CupertinoColors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final sx = size.width / 24;
    final sy = size.height / 24;
    final path = Path()
      ..moveTo(11 * sx, 6 * sy)
      ..lineTo(5 * sx, 12 * sy)
      ..lineTo(11 * sx, 18 * sy)
      ..moveTo(5 * sx, 12 * sy)
      ..lineTo(19 * sx, 12 * sy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GenderIconPainter extends CustomPainter {
  const _GenderIconPainter({required this.male});
  final bool male;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final sx = size.width / 24;
    final sy = size.height / 24;
    if (male) {
      canvas.drawCircle(Offset(9 * sx, 15 * sy), 7 * sx, paint);
      final path = Path()
        ..moveTo(15 * sx, 3 * sy)
        ..lineTo(21 * sx, 3 * sy)
        ..lineTo(21 * sx, 9 * sy)
        ..moveTo(20 * sx, 4 * sy)
        ..lineTo(14.8 * sx, 9.2 * sy);
      canvas.drawPath(path, paint);
    } else {
      canvas.drawCircle(Offset(12 * sx, 8 * sy), 5 * sx, paint);
      final path = Path()
        ..moveTo(12 * sx, 13 * sy)
        ..lineTo(12 * sx, 21 * sy)
        ..moveTo(9 * sx, 18 * sy)
        ..lineTo(15 * sx, 18 * sy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GenderIconPainter oldDelegate) =>
      oldDelegate.male != male;
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.save();
    canvas.scale(scale);
    final paths = <(Color, String)>[
      (
        const Color(0xFF4285F4),
        'M21.6 12.23 C21.6 11.52 21.54 10.83 21.42 10.16 L12 10.16 L12 14.08 L17.38 14.08 C17.15 15.34 16.44 16.41 15.38 17.1 L15.38 19.64 L18.62 19.64 C20.52 17.89 21.6 15.32 21.6 12.23 Z',
      ),
      (
        const Color(0xFF34A853),
        'M12 22 C14.7 22 16.97 21.1 18.62 19.64 L15.38 17.1 C14.48 17.7 13.33 18.06 12 18.06 C9.39 18.06 7.18 16.3 6.39 13.93 L3.04 13.93 L3.04 16.55 C4.68 19.8 8.06 22 12 22 Z',
      ),
      (
        const Color(0xFFFBBC05),
        'M6.39 13.93 C6.18 13.32 6.07 12.67 6.07 12 C6.07 11.33 6.19 10.68 6.39 10.07 L6.39 7.45 L3.04 7.45 C2.38 8.86 2 10.39 2 12 C2 13.61 2.38 15.14 3.04 16.55 L6.39 13.93 Z',
      ),
      (
        const Color(0xFFEA4335),
        'M12 5.94 C13.47 5.94 14.79 6.45 15.83 7.44 L18.7 4.56 C16.95 2.93 14.7 2 12 2 C8.06 2 4.68 4.2 3.04 7.45 L6.39 10.07 C7.18 7.7 9.39 5.94 12 5.94 Z',
      ),
    ];
    for (final (color, svg) in paths) {
      canvas.drawPath(_parseSimpleSvgPath(svg), Paint()..color = color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AppleLogoPainter extends CustomPainter {
  const _AppleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.save();
    canvas.scale(scale);
    final body = Path()
      ..moveTo(17.05, 12.54)
      ..cubicTo(17.08, 15.61, 19.74, 16.63, 19.77, 16.65)
      ..cubicTo(19.75, 16.72, 19.34, 18.13, 18.37, 19.59)
      ..cubicTo(17.53, 20.85, 16.66, 22.1, 15.29, 22.13)
      ..cubicTo(13.95, 22.16, 13.51, 21.33, 11.98, 21.33)
      ..cubicTo(10.44, 21.33, 9.96, 22.1, 8.69, 22.16)
      ..cubicTo(7.37, 22.21, 6.36, 20.84, 5.51, 19.59)
      ..cubicTo(3.78, 17.09, 2.46, 12.52, 4.23, 9.44)
      ..cubicTo(5.11, 7.91, 6.69, 6.94, 8.42, 6.9)
      ..cubicTo(9.73, 6.88, 10.96, 7.78, 11.73, 7.78)
      ..cubicTo(12.5, 7.78, 13.95, 6.69, 15.47, 6.85)
      ..cubicTo(16.11, 6.88, 17.9, 7.11, 19.05, 8.79)
      ..cubicTo(18.96, 8.85, 16.91, 10.04, 16.94, 12.54)
      ..close();
    final leaf = Path()
      ..moveTo(14.48, 5.25)
      ..cubicTo(15.18, 4.4, 15.65, 3.22, 15.52, 2.05)
      ..cubicTo(14.51, 2.09, 13.29, 2.72, 12.57, 3.56)
      ..cubicTo(11.92, 4.3, 11.35, 5.5, 11.5, 6.64)
      ..cubicTo(12.62, 6.73, 13.77, 6.07, 14.48, 5.25)
      ..close();
    final paint = Paint()..color = CupertinoColors.black;
    canvas.drawPath(body, paint);
    canvas.drawPath(leaf, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Path _parseSimpleSvgPath(String data) {
  final tokens = RegExp(
    r'[A-Za-z]|-?\d*\.?\d+',
  ).allMatches(data).map((match) => match.group(0)!).toList();
  var index = 0;
  var command = '';
  final path = Path();
  double number() => double.parse(tokens[index++]);
  while (index < tokens.length) {
    if (RegExp(r'[A-Za-z]').hasMatch(tokens[index])) {
      command = tokens[index++];
    }
    switch (command) {
      case 'M':
        path.moveTo(number(), number());
        break;
      case 'L':
        path.lineTo(number(), number());
        break;
      case 'C':
        path.cubicTo(
          number(),
          number(),
          number(),
          number(),
          number(),
          number(),
        );
        break;
      case 'Z':
      case 'z':
        path.close();
        break;
      default:
        index++;
    }
  }
  return path;
}

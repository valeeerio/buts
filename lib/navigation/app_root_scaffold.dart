import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/buste_paga/buste_paga_section_screen.dart';
import '../widgets/app_section_header.dart';
import 'app_section.dart';
import 'app_section_provider.dart';
import 'root_scaffold.dart';

/// Scaffold radice assoluto dell'app: header persistente con indicatore di
/// sezione + PageView orizzontale a 2 pagine (Buste Paga, Budget). Lo swipe
/// sul contenuto e il tap sulla freccia dell'header portano entrambi allo
/// stesso risultato — PageView.onPageChanged resta l'unica fonte di verità
/// per activeSectionProvider.
class AppRootScaffold extends ConsumerStatefulWidget {
  const AppRootScaffold({super.key});

  @override
  ConsumerState<AppRootScaffold> createState() => _AppRootScaffoldState();
}

class _AppRootScaffoldState extends ConsumerState<AppRootScaffold> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: AppSection.bustePaga.index,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateTo(AppSection section) {
    _pageController.animateToPage(
      section.index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppSectionHeader(onNavigate: _navigateTo),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (i) => ref.read(activeSectionProvider.notifier).state =
                AppSection.orderedSections[i],
            children: const [
              BustePagaSectionScreen(),
              RootScaffold(),
            ],
          ),
        ),
      ],
    );
  }
}

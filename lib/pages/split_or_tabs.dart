import 'package:flutter/material.dart';
import 'package:split_view/split_view.dart';

import '../theme/brand_colors.dart';

class SplitOrTabs extends StatefulWidget {
  const SplitOrTabs({required this.tabs, required this.children, super.key});
  final List<Widget> tabs;
  final List<Widget> children;

  @override
  State<SplitOrTabs> createState() => _SplitOrTabsState();
}

class _SplitOrTabsState extends State<SplitOrTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    if (isWide) {
      return ColoredBox(
        color: backgroundTone,
        child: SplitView(
          controller: SplitViewController(
            weights: [0.3, 0.7],
            limits: [WeightLimit(min: 0.2), WeightLimit(min: 0.4)],
          ),
          viewMode: SplitViewMode.Horizontal,

          // grip은 숨기고, 인디케이터만 은은하게
          gripColor: Colors.transparent,
          gripColorActive: Colors.transparent,

          indicator: SplitIndicator(
            viewMode: SplitViewMode.Horizontal,
            color: brandSecondary.withOpacity(0.35),
          ),
          activeIndicator: SplitIndicator(
            viewMode: SplitViewMode.Horizontal,
            isActive: true,
            color: brandPrimary.withOpacity(0.65),
          ),

          children: widget.children,
        ),
      );
    }

    return ColoredBox(
      color: backgroundTone,
      child: Column(
        children: [
          // 탭바를 한지톤 배경 위에 카드처럼
          Material(
            color: backgroundTone,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 2), // 더 얇게
              decoration: BoxDecoration(
                color: backgroundTone,
                border: Border(
                  bottom: BorderSide(color: brandSecondary.withOpacity(0.30)),
                ),
              ),
              child: SizedBox(
                height: 40, // 탭 높이 줄이기
                child: TabBar(
                  controller: _tabController,
                  tabs: widget.tabs,

                  // 텍스트 톤
                  labelColor: brandPrimary,
                  unselectedLabelColor: brandPrimary.withOpacity(0.55),

                  // 탭 간격/여백 줄이기
                  labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                  indicatorSize: TabBarIndicatorSize.label,

                  // 인디케이터 얇고 짧게
                  indicator: UnderlineTabIndicator(
                    borderSide: BorderSide(
                      color: brandSecondary.withOpacity(0.95),
                      width: 2, // 3 -> 2
                    ),
                    insets: const EdgeInsets.symmetric(horizontal: 12),
                  ),

                  // 터치 피드백도 은은하게
                  overlayColor: WidgetStatePropertyAll(
                    brandSecondary.withOpacity(0.10),
                  ),

                  // 글자 크기 살짝 다운
                  labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                  unselectedLabelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: widget.children,
            ),
          ),
        ],
      ),
    );
  }
}
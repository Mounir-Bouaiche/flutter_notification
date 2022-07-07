part of 'app.dart';

final _router = GoRouter(
  routes: <GoRoute>[
    GoRoute(
      name: 'home',
      path: SampleItemListView.routeName,
      pageBuilder: (BuildContext context, GoRouterState state) {
        return const MaterialPage(
          child: SampleItemListView(),
        );
      },
    ),
  ],
);

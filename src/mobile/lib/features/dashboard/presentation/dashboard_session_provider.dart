import 'dart:async';

import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:lingoroad_mobile/features/dashboard/presentation/dashboard_view_model.dart';
import 'package:provider/provider.dart';

ChangeNotifierProxyProvider<SessionController, DashboardViewModel>
    dashboardViewModelProvider() =>
        ChangeNotifierProxyProvider<SessionController, DashboardViewModel>(
          create: (context) => DashboardViewModel(
            context.read<DashboardRepository>(),
            sessionGeneration:
                context.read<SessionController>().sessionGeneration,
          ),
          update: (context, session, previous) {
            final viewModel = previous ??
                DashboardViewModel(
                  context.read<DashboardRepository>(),
                  sessionGeneration: session.sessionGeneration,
                );
            viewModel.updateSessionGeneration(session.sessionGeneration);

            if (session.status == SessionStatus.authenticated &&
                session.placementStatus ==
                    PlacementOnboardingStatus.completed &&
                viewModel.state == DashboardState.initial) {
              final sessionGeneration = session.sessionGeneration;
              unawaited(Future<void>.microtask(() async {
                if (session.status != SessionStatus.authenticated ||
                    session.placementStatus !=
                        PlacementOnboardingStatus.completed ||
                    session.sessionGeneration != sessionGeneration ||
                    viewModel.sessionGeneration != sessionGeneration ||
                    viewModel.state != DashboardState.initial) {
                  return;
                }
                await viewModel.load();
              }));
            }
            return viewModel;
          },
        );

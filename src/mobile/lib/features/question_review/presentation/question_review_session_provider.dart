import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/features/question_review/data/question_review_repository.dart';
import 'package:lingoroad_mobile/features/question_review/presentation/question_review_view_model.dart';
import 'package:provider/provider.dart';

ChangeNotifierProxyProvider<SessionController, QuestionReviewViewModel>
    questionReviewViewModelProvider() =>
        ChangeNotifierProxyProvider<SessionController,
            QuestionReviewViewModel>(
          create: (context) => QuestionReviewViewModel(
            context.read<QuestionReviewRepository>(),
            sessionGeneration:
                context.read<SessionController>().sessionGeneration,
          ),
          update: (context, session, previous) {
            final viewModel = previous ??
                QuestionReviewViewModel(
                  context.read<QuestionReviewRepository>(),
                  sessionGeneration: session.sessionGeneration,
                );
            viewModel.updateSessionGeneration(session.sessionGeneration);
            return viewModel;
          },
        );

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/news_viewmodel.dart';
import '../widgets/news_article_card.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Newsroom'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<NewsViewModel>().refreshArticles();
            },
          ),
        ],
      ),
      body: Consumer<NewsViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const LoadingView();
          }

          if (viewModel.error != null) {
            return ErrorView(
              message: viewModel.error!,
              onRetry: viewModel.refreshArticles,
            );
          }

          if (viewModel.articles.isEmpty) {
            return const Center(
              child: Text('No articles available'),
            );
          }

          return RefreshIndicator(
            onRefresh: viewModel.refreshArticles,
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: viewModel.articles.length,
              itemBuilder: (context, index) {
                final article = viewModel.articles[index];
                return NewsArticleCard(article: article);
              },
            ),
          );
        },
      ),
    );
  }
} 
package com.example.newsroom

import java.util.Date

data class NewsItem(
    val title: String,
    val content: String,
    val imageUrl: String,
    val articleUrl: String,
    val date: Date
) 
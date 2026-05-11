package com.example.models

import kotlinx.serialization.Serializable

@Serializable
data class Item(val id: Int, val name: String, val description: String)

@Serializable
data class ItemCreate(val name: String, val description: String)

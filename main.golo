module main

import m33ki.spark
import java.io.File

augment java.util.ArrayList {
  function extract = |this, start, end| {
    if this: size() < (end - start) {
      return this: subList(start, this: size())
    } else {
      return this: subList(start, end)
    }
  }
}

function sharedPreferences = |reviews, user1, user2| ->
  reviews: get(user1)
    : filter(|film, notation| -> reviews: get(user2): get(film) isnt null)
    : keySet()

function distance = |reviews, user1, user2| {
  let shared_preferences = sharedPreferences(reviews, user1, user2)
  let sum_of_squares = map[[0,0.0]]
  if shared_preferences: isEmpty() { return 0.0 }

  shared_preferences: each(|film| {
    sum_of_squares: put(0, sum_of_squares: get(0) +
      java.lang.Math.pow(
        reviews: get(user1): get(film): doubleValue() - reviews: get(user2): get(film): doubleValue()
        , 2.0
      ))
  })
  return 1/(1 + java.lang.Math.sqrt(sum_of_squares: get(0)))
}

function main = |args| {

  initialize(): static("/public"): port(3000)

  let ratings = map[]

  let path = File("."): getCanonicalPath()
  let mapper = com.fasterxml.jackson.databind.ObjectMapper()
  let moviesList = mapper: readValue(File(path + "/json/movies.json"), java.util.List.class)
  let usersList = mapper: readValue(File(path + "/json/users.json"), java.util.List.class)

  let jsonMoviesList = mapper: writeValueAsString(moviesList)
  let jsonUsersList = mapper: writeValueAsString(usersList)

  POST("/rates", |request, response| {
    response: type("application/json")
    #let rate =  Json(): toTreeMap(request: body())
    let rate = mapper: treeToValue(mapper: readValue(request: body(), com.fasterxml.jackson.databind.JsonNode.class), java.util.TreeMap.class)

    #response: status(201) # 201: created
    #header ???
    let userRates = ratings: get(rate: get("userId"))

    if userRates is null { # new
      ratings: put(rate: get("userId"), map[[rate: get("movieId"), rate: get("rate")]])
    } else {
      ratings: get(rate: get("userId")): put(rate: get("movieId"), rate: get("rate"))
    }

    response: redirect("/rates/"+rate: get("userId"): toString(),301)

    #return mapper: writeValueAsString(rate)
    #return Json(): toJsonString(rate)
  })

  GET("/rates/:userid1", |request, response| {
    response: type("application/json")
    return mapper: writeValueAsString(
      ratings: get(request: params(":userid1"): toInteger())
    )
  })

  GET("/users/share/:userid1/:userid2", |request, response| {
    response: type("application/json")
    let userid1 = request: params(":userid1"): toInteger()
    let userid2 = request: params(":userid2"): toInteger()

    return mapper: writeValueAsString(sharedPreferences(ratings, userid1, userid2))
  })

  GET("/users/distance/:userid1/:userid2", |request, response| {
    response: type("application/json")
    let userid1 = request: params(":userid1"): toInteger()
    let userid2 = request: params(":userid2"): toInteger()

    return mapper: writeValueAsString(map[["distance", distance(ratings, userid1, userid2)]])
  })

  GET("/movies", |request, response| {
    response: type("application/json")
    return jsonMoviesList
  })

  GET("/movies/:id", |request, response| {
    response: type("application/json")
    return mapper: writeValueAsString(
      moviesList: filter(|movie| ->
        movie: get("_id"): toString(): equals(request: params(":id"): toString()))
    )
  })

  GET("/movies/search/title/:title/:limit", |request, response| {
    response: type("application/json")
    let title = request: params(":title"): toString()
    let limit = request: params(":limit"): toString(): toInteger()
    return mapper: writeValueAsString(
      moviesList: filter(|movie| ->
        movie: get("Title"): toString(): toLowerCase(): contains(title)): extract(0, limit)
    )
  })

  GET("/movies/search/genre/:genre/:limit", |request, response| {
    response: type("application/json")
    let genre = request: params(":genre"): toString()
    let limit = request: params(":limit"): toString(): toInteger()
    return mapper: writeValueAsString(
      moviesList: filter(|movie| ->
        movie: get("Genre"): toString(): toLowerCase(): contains(genre)): extract(0, limit)
    )
  })

  GET("/movies/search/actors/:actors/:limit", |request, response| {
    response: type("application/json")
    let actors = request: params(":actors"): toString()
    let limit = request: params(":limit"): toString(): toInteger()
    return mapper: writeValueAsString(
      moviesList: filter(|movie| ->
        movie: get("Actors"): toString(): toLowerCase(): contains(actors)): extract(0, limit)
    )
  })

  GET("/users", |request, response| {
    response: type("application/json")
    return jsonUsersList
  })

  GET("/users/:id", |request, response| {
    response: type("application/json")
    return mapper: writeValueAsString(
      usersList: filter(|user| ->
        user: get("_id"): toString(): equals(request: params(":id"): toString())
      ))
  })

  GET("/users/search/:name/:limit", |request, response| {
    response: type("application/json")
    let name = request: params(":name"): toString()
    let limit = request: params(":limit"): toString(): toInteger()
    return mapper: writeValueAsString(
      usersList: filter(|user| ->
        user: get("name"): toString(): toLowerCase(): contains(name)): extract(0, limit)
    )
  })

}

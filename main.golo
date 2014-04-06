module main

import m33ki.spark
import m33ki.hot # requisite for "hot reloading"
import m33ki.jackson

import java.io.File

struct vo = { value }

augment vo {
	function add = |this, n| {
    this: value(this: value() + n)
		return this
	}
}

augment java.util.ArrayList {
  function extract = |this, start, end| {
    if this: size() < (end - start) {
      return this: subList(start, this: size())
    } else {
      return this: subList(start, end)
    }
  }
}

function Preco = |reviews| {
  return DynamicObject()
    : reviews(reviews)
    : sharedPreferences(|this, user1, user2| ->
        this: reviews(): get(user1)
          : filter(|film, notation| -> this: reviews(): get(user2): get(film) isnt null)
          : keySet()
    )
    : distance(|this, user1, user2| { # Euclidean distance
        let shared_preferences = this: sharedPreferences(user1, user2)
        let sum_of_squares = vo(0)
        if shared_preferences: isEmpty() { return 0 }

        shared_preferences: each(|film| {
          sum_of_squares: add(
            java.lang.Math.pow(
              this: reviews(): get(user1): get(film): doubleValue() - this: reviews(): get(user2): get(film): doubleValue()
              , 2.0
            )
          )
        })
        return 1/(1 + java.lang.Math.sqrt(sum_of_squares: value()))
    })
}




function main = |args| {

  initialize(): static("/public"): port(3000)
  #listen(true) # listen to change, then compile java file

  let ratings = map[]

  let path = File("."): getCanonicalPath()
  let mapper = com.fasterxml.jackson.databind.ObjectMapper()
  let moviesList = mapper: readValue(File(path + "/json/movies.json"), java.util.List.class)
  let usersList = mapper: readValue(File(path + "/json/users.json"), java.util.List.class)


  POST("/rates", |request, response| {
    response: type("application/json")
    let rate =  Json(): toTreeMap(request: body())
    response: status(201) # 201: created
    #header ???
    let userRates = ratings: get(rate: get("userId"))

    if userRates is null { # new
      ratings: put(rate: get("userId"), map[[rate: get("movieId"), rate: get("rate")]])
    } else {
      ratings: get(rate: get("userId")): put(rate: get("movieId"), rate: get("rate"))
    }
    return Json(): toJsonString(rate)
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
    let preco = Preco(ratings)
    return mapper: writeValueAsString(preco: sharedPreferences(userid1, userid2))
  })

  GET("/users/distance/:userid1/:userid2", |request, response| {
    response: type("application/json")
    let userid1 = request: params(":userid1"): toInteger()
    let userid2 = request: params(":userid2"): toInteger()
    let preco = Preco(ratings)
    return mapper: writeValueAsString(map[["distance", preco: distance(userid1, userid2)]])
  })

  GET("/movies", |request, response| {
    response: type("application/json")
    return mapper: writeValueAsString(moviesList)
  })

  GET("/movies/:id", |request, response| {
    response: type("application/json")
    return mapper: writeValueAsString(
      moviesList: filter(|movie|->
        movie: get("_id"): toString(): equals(request: params(":id"): toString()))
    )
  })

  GET("/movies/search/title/:title/:limit", |request, response| {
    response: type("application/json")
    let title = request: params(":title"): toString()
    let limit = request: params(":limit"): toString(): toInteger()
    return mapper: writeValueAsString(
      moviesList: filter(|movie|->
        movie: get("Title"): toString(): toLowerCase(): contains(title)): extract(0, limit)
    )
  })

  GET("/movies/search/genre/:genre/:limit", |request, response| {
    response: type("application/json")
    let genre = request: params(":genre"): toString()
    let limit = request: params(":limit"): toString(): toInteger()
    return mapper: writeValueAsString(
      moviesList: filter(|movie|->
        movie: get("Genre"): toString(): toLowerCase(): contains(genre)): extract(0, limit)
    )
  })

  GET("/movies/search/actors/:actors/:limit", |request, response| {
    response: type("application/json")
    let actors = request: params(":actors"): toString()
    let limit = request: params(":limit"): toString(): toInteger()
    return mapper: writeValueAsString(
      moviesList: filter(|movie|->
        movie: get("Actors"): toString(): toLowerCase(): contains(actors)): extract(0, limit)
    )
  })

  GET("/users", |request, response| {
    response: type("application/json")
    return mapper: writeValueAsString(usersList)
  })

  GET("/users/:id", |request, response| {
    response: type("application/json")
    return mapper: writeValueAsString(
      usersList: filter(|user|->
        user: get("_id"): toString(): equals(request: params(":id"): toString())
      ))
  })

  GET("/users/search/:name/:limit", |request, response| {
    response: type("application/json")
    let name = request: params(":name"): toString()
    let limit = request: params(":limit"): toString(): toInteger()
    return mapper: writeValueAsString(
      usersList: filter(|user|->
        user: get("name"): toString(): toLowerCase(): contains(name)): extract(0, limit)
    )
  })


}
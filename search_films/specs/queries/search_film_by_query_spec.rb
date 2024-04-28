require_relative "../queries/search_film_by_query"

RSpec.describe Queries::SearchFilmsByQuery do
  let(:response) {
    {
      "page": 1,
      "results": [
        {
          "adult": false,
          "backdrop_path": "/frDS8A5vIP927KYAxTVVKRIbqZw.jpg",
          "genre_ids": [
            14,
            28,
            80
          ],
          "id": 268,
          "original_language": "en",
          "original_title": "Batman",
          "overview": "Batman must face his most ruthless nemesis when a deformed madman calling himself \"The Joker\" seizes control of Gotham's criminal underworld.",
          "popularity": 78.491,
          "poster_path": "/cij4dd21v2Rk2YtUQbV5kW69WB2.jpg",
          "release_date": "1989-06-21",
          "title": "Batman",
          "video": false,
          "vote_average": 7.229,
          "vote_count": 7482
        },
        {
          "adult": false,
          "backdrop_path": "/bxxupqG6TBLKC60M6L8iOvbQEr6.jpg",
          "genre_ids": [
            28,
            35,
            80
          ],
          "id": 2661,
          "original_language": "en",
          "original_title": "Batman",
          "overview": "The Dynamic Duo faces four super-villains who plan to hold the world for ransom with the help of a secret invention that instantly dehydrates people.",
          "popularity": 30.634,
          "poster_path": "/zzoPxWHnPa0eyfkMLgwbNvdEcVF.jpg",
          "release_date": "1966-07-30",
          "title": "Batman",
          "video": false,
          "vote_average": 6.388,
          "vote_count": 855
        },
        {
          "adult": false,
          "backdrop_path": "/bHxJA9rllKF2jhb11ARAwZJYSp6.jpg",
          "genre_ids": [
            28,
            12,
            80,
            878,
            53,
            10752
          ],
          "id": 125249,
          "original_language": "en",
          "original_title": "Batman",
          "overview": "Japanese master spy Daka operates a covert espionage-sabotage organization located in Gotham City's now-deserted Little Tokyo, which turns American scientists into pliable zombies. The great crime-fighters Batman and Robin, with the help of their allies, are in pursuit.",
          "popularity": 31.954,
          "poster_path": "/AvzD3mrtokIzZOiV6zAG7geIo6F.jpg",
          "release_date": "1943-07-16",
          "title": "Batman",
          "video": false,
          "vote_average": 6.435,
          "vote_count": 77
        }
      ],
      "total_pages": 9,
      "total_results": 161
    }
  }
end
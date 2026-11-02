local Board = require("domain.match3_board")
local Matcher = require("domain.match3_matcher")
local Resolver = require("domain.match3_resolver")
local Rng = require("domain.match3_rng")

return {
  Board = Board,
  Matcher = Matcher,
  Resolver = Resolver,
  Rng = Rng,
  new_board = Board.generate,
  try_swap = Resolver.try_swap,
  find_matches = Matcher.find,
  legal_moves = Board.legal_moves,
  reshuffle = Board.reshuffle,
}

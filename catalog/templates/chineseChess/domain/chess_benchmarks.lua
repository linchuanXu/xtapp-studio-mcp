-- Fixed regression positions for the local Xiangqi engine.  They are kept in
-- the app bundle so future strength work can be checked without any network or
-- third-party game database.
local M = {}

M.cases = {
  {
    id = "poisoned-cannon",
    board =
      "....K...." .. "R........" .. "........." .. "c.r......" .. "....P...." ..
      "........." .. "........." .. "........." .. "........." .. "....k....",
    side = "b", difficulty = 2, budget_ms = 9500,
    accepted_moves = {},
    forbidden_moves = { { r = 1, c = 0, tr = 3, tc = 0 } },
    note = "Do not trade the cannon for a defended rook without compensation.",
  },
  {
    id = "forced-defense",
    board =
      "....K...." .. "........." .. "........." .. "....r...." .. "........." ..
      "........." .. "........." .. "........." .. "........." .. "....k....",
    side = "b", difficulty = 1, budget_ms = 9500,
    defense_case = true, defense_kind = "check-evasion",
    accepted_moves = {
      { r = 0, c = 4, tr = 0, tc = 3 },
      { r = 0, c = 4, tr = 0, tc = 5 },
    },
    forbidden_moves = {},
    note = "A checked side must prioritize legal king safety over material.",
  },
  {
    id = "repeat-penalty",
    board =
      "RNBAKABNR" .. "........." .. ".C.....C." .. "P.P.P.P.P" .. "........." ..
      "........." .. "p.p.p.p.p" .. ".c.....c." .. "........." .. "rnbakabnr",
    side = "b", difficulty = 1, budget_ms = 9500,
    accepted_moves = {}, forbidden_moves = {},
    note = "Quiet reverse moves need a visible penalty outside forced defense.",
  },
  {
    id = "one-step-mate",
    board =
      "....K...." .. "....R...." .. "........." .. "........." .. "........." ..
      "........." .. "........." .. "........." .. "........." .. "....k....",
    side = "b", difficulty = 3, budget_ms = 9500,
    attack_case = true, attack_kind = "mate",
    accepted_moves = { { r = 1, c = 4, tr = 9, tc = 4 } },
    forbidden_moves = {},
    note = "A direct general capture must be found as a one-step mate.",
  },
  {
    id = "forcing-check",
    board =
      "...K....." .. "..n.n...." .. "........." .. "R..r....." .. "........." ..
      "........." .. "........." .. "........." .. "........." .. "...k.....",
    side = "b", difficulty = 3, budget_ms = 9500,
    defense_case = true, defense_kind = "check-evasion",
    accepted_moves = { { r = 3, c = 0, tr = 3, tc = 3 } },
    forbidden_moves = {},
    note = "Capture the checking rook with countercheck; the horse pair covers both general escapes.",
  },
  {
    id = "blocked-horse-leg",
    board =
      "....K...." .. "........." .. "..N......" .. "..P......" .. "...r....." ..
      "....P...." .. "........." .. "........." .. "........." .. "....k....",
    side = "b", difficulty = 2, budget_ms = 9500,
    accepted_moves = {}, forbidden_moves = {},
    note = "The occupied downward leg removes the apparent horse capture.",
  },
  {
    id = "cannon-screen-mate",
    board =
      "...K....." .. "....C...." .. "........." .. "........." .. "........." ..
      "....P...." .. "........." .. "........." .. "........." .. "....k....",
    side = "b", difficulty = 3, budget_ms = 9500,
    attack_case = true, attack_kind = "mate",
    accepted_moves = { { r = 1, c = 4, tr = 9, tc = 4 } },
    forbidden_moves = {},
    note = "Use the single pawn screen to deliver the cannon capture.",
  },
  {
    id = "pawn-endgame-advance",
    board =
      "....K...." .. "r........" .. "....n...." .. "........." .. "....P...." ..
      "........." .. "........." .. "........." .. "........." .. "....k....",
    side = "b", difficulty = 2, budget_ms = 9500,
    accepted_moves = { { r = 4, c = 4, tr = 5, tc = 4 } },
    forbidden_moves = {},
    note = "Advance the only mobile black piece through the red rook-and-horse king net.",
  },
  {
    id = "continuous-attack",
    board =
      "....K...." .. "...A....." .. "..N......" .. "r........" .. "........." ..
      "........." .. "........." .. "........." .. "...r....." .. ".....k...",
    side = "r", difficulty = 2, budget_ms = 9500,
    attack_case = true, attack_kind = "check",
    motif = "continuousAttack",
    accepted_moves = {
      { r = 3, c = 0, tr = 3, tc = 4 },
      { r = 8, c = 3, tr = 8, tc = 4 },
    },
    forbidden_moves = {},
    note = "Keep forcing pressure with either verified checking continuation.",
  },
  {
    id = "blocking-defense",
    board =
      "....K...." .. "R........" .. "........." .. "....r...." .. "........." ..
      "........." .. "........." .. "........." .. "........." .. "...k.....",
    side = "b", difficulty = 1, budget_ms = 9500,
    defense_case = true, defense_kind = "check-evasion",
    motif = "blocking",
    accepted_moves = { { r = 1, c = 0, tr = 1, tc = 4 } },
    forbidden_moves = {},
    note = "Interpose the rook on the central file instead of merely fleeing.",
  },
  {
    id = "favorable-exchange",
    board =
      "....K...." .. "........." .. "........." .. "R..c....." .. "........." ..
      "....P...." .. "........." .. "........." .. "........." .. "....k....",
    side = "b", difficulty = 2, budget_ms = 9500,
    attack_case = true, attack_kind = "material",
    motif = "favorableExchange",
    accepted_moves = { { r = 3, c = 0, tr = 3, tc = 3 } },
    forbidden_moves = {},
    note = "Take the loose cannon before it can escape.",
  },
  {
    id = "avoid-pointless-back-and-forth",
    board =
      "R...K...." .. "........." .. "........." .. "........." .. "........." ..
      "....P...." .. "........." .. "........." .. "........." .. "....k....",
    side = "b", difficulty = 1, budget_ms = 9500, motif = "avoidReversal",
    accepted_moves = {},
    forbidden_moves = { { r = 0, c = 0, tr = 1, tc = 0 } },
    move_history = { { side = "b", r = 1, c = 0, tr = 0, tc = 0 } },
    last_move = { r = 1, c = 0, tr = 0, tc = 0 },
    note = "Use played move history to avoid immediately reversing the rook.",
  },
  {
    id = "avoid-repeat-check",
    board =
      "....K...." .. "........." .. "........." ..
      "........." .. "........." .. "........." ..
      "....p...." .. "........." .. "........." .. "R........",
    side = "b", difficulty = 1, budget_ms = 9500,
    motif = "avoidReversal",
    accepted_moves = {},
    forbidden_moves = { { r = 9, c = 0, tr = 8, tc = 0 } },
    move_history = {
      { side = "b", r = 8, c = 0, tr = 9, tc = 0 },
      { side = "r", r = 9, c = 4, tr = 8, tc = 4 },
    },
    last_move = { r = 9, c = 4, tr = 8, tc = 4 },
    note = "Do not repeat the same rook check after the opposing general evades.",
  },
  {
    id = "recognize-player-mating-threat",
    board =
      "...PKP..." .. "........." .. "r........" .. "........." .. "........." ..
      "........." .. "........." .. "........." .. "........." .. "...k.....",
    side = "b", difficulty = 1, budget_ms = 9500,
    defense_case = true, defense_kind = "mate-threat",
    motif = "matingThreatRecognition",
    accepted_moves = {
      { r = 0, c = 3, tr = 1, tc = 3 },
      { r = 0, c = 4, tr = 1, tc = 4 },
      { r = 0, c = 5, tr = 1, tc = 5 },
    },
    forbidden_moves = {},
    note = "Create flight before the player can play rook-to-center mate.",
  },
}

return M

-- Test/benchmark-only opening-move ranking diagnostics.
-- Kept out of the shipped app bundle (not required by index.lua).
local State = require("domain.chess_state")
local Evaluation = require("domain.chess_evaluation")
local M = {}

local WIN = 8888

local function other(side) return side == "r" and "b" or "r" end

local function opening_move(candidate)
  return candidate and (candidate.move or candidate) or nil
end

local function opening_major_piece_value(piece, side)
  if State.side_of(piece) ~= side then return 0 end
  local kind = piece:lower()
  if kind == "r" then return 3 end
  if kind == "c" then return 2 end
  if kind == "n" then return 1 end
  return 0
end

local function opening_precedes(left, right)
  if left.score ~= right.score then return left.score > right.score end
  if left.support ~= right.support then return left.support > right.support end
  return left.corpus_index < right.corpus_index
end

local function insert_opening_ranked(ranking, candidate, move, score)
  local item = {
    move = { r = move.r, c = move.c, tr = move.tr, tc = move.tc },
    support = candidate.support,
    corpus_index = candidate.corpus_index,
    score = score,
  }
  local index = #ranking.ranked + 1
  while index > 1 and opening_precedes(item, ranking.ranked[index - 1]) do
    ranking.ranked[index] = ranking.ranked[index - 1]
    index = index - 1
  end
  ranking.ranked[index] = item
end

function M.begin_opening_ranking(s, candidates)
  return {
    board = s.board, side = s.turn, candidates = candidates or {},
    candidate_index = 1, ranked = {}, stage = "candidate", done = false,
  }
end

local function advance_opening_candidate(ranking)
  ranking.candidate_index = ranking.candidate_index + 1
  ranking.candidate = nil
  ranking.move = nil
  ranking.candidate_board = nil
  ranking.candidate_score = nil
  ranking.reply_cursor = nil
  ranking.reply_index = nil
  ranking.reply_board = nil
  ranking.reply_evasion_cursor = nil
  ranking.unsafe = nil
  ranking.stage = "candidate"
end

function M.resume_opening_ranking(ranking, should_stop)
  while ranking.candidate_index <= #ranking.candidates do
    if should_stop and should_stop() then return false end
    if ranking.stage == "candidate" then
      local candidate = ranking.candidates[ranking.candidate_index]
      local move = opening_move(candidate)
      if not move or not State.is_legal(
        { board = ranking.board, turn = ranking.side },
        move.r, move.c, move.tr, move.tc
      ) then
        advance_opening_candidate(ranking)
      else
        ranking.candidate = candidate
        ranking.move = move
        ranking.candidate_board = State.apply_pure(
          ranking.board, move.r, move.c, move.tr, move.tc
        )
        if should_stop and should_stop() then return false end
        ranking.candidate_score = Evaluation.material_score(
          ranking.candidate_board, ranking.side
        )
        ranking.reply_cursor = State.begin_board_moves(
          ranking.candidate_board, other(ranking.side)
        )
        ranking.stage = "generate_replies"
        if should_stop and should_stop() then return false end
      end
    elseif ranking.stage == "generate_replies" then
      State.resume_board_moves(ranking.reply_cursor, should_stop)
      if not ranking.reply_cursor.done then return false end
      ranking.reply_index = 1
      ranking.unsafe = false
      ranking.stage = "inspect_replies"
    elseif ranking.stage == "inspect_replies" then
      local replies = ranking.reply_cursor.moves
      if ranking.reply_index > #replies then
        if #replies == 0 then ranking.candidate_score = WIN end
        if not ranking.unsafe then
          insert_opening_ranked(
            ranking, ranking.candidate, ranking.move, ranking.candidate_score
          )
        end
        advance_opening_candidate(ranking)
      else
        local reply = replies[ranking.reply_index]
        local reply_board = State.apply_pure(
          ranking.candidate_board, reply.r, reply.c, reply.tr, reply.tc
        )
        if should_stop and should_stop() then return false end
        local captured_major = opening_major_piece_value(
          State.at(ranking.candidate_board, reply.tr, reply.tc), ranking.side
        )
        if captured_major > 0 then
          ranking.unsafe = true
          advance_opening_candidate(ranking)
        elseif State.board_in_check(reply_board, ranking.side) then
          ranking.reply_board = reply_board
          ranking.reply_evasion_cursor = State.begin_board_moves(
            reply_board, ranking.side
          )
          ranking.stage = "check_evasions"
        else
          ranking.reply_index = ranking.reply_index + 1
        end
        if should_stop and should_stop() then return false end
      end
    elseif ranking.stage == "check_evasions" then
      State.resume_board_moves(ranking.reply_evasion_cursor, should_stop)
      if not ranking.reply_evasion_cursor.done then return false end
      if #ranking.reply_evasion_cursor.moves == 0 then
        ranking.unsafe = true
        advance_opening_candidate(ranking)
      else
        ranking.reply_board = nil
        ranking.reply_evasion_cursor = nil
        ranking.reply_index = ranking.reply_index + 1
        ranking.stage = "inspect_replies"
      end
      if should_stop and should_stop() then return false end
    end
  end
  ranking.done = true
  return true
end

function M.rank_opening_candidates(s, candidates)
  local ranking = M.begin_opening_ranking(s, candidates)
  M.resume_opening_ranking(ranking)
  return ranking.ranked
end

return M

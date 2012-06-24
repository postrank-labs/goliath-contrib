#!/usr/bin/env ruby
require 'fiber'
require 'eventmachine'

FIBER_IDXS = {}

def fiber_idx
  FIBER_IDXS[Fiber.current.object_id] ||= FIBER_IDXS.length
end

$order = 0

def ll indent, where, guess, desc
  info = (fiber_idx == 0 ? "#{" "*indent} #{where} #{" "*20}" : "#{" "*(indent+20)} #{where}")
  $stderr.puts "%8s %3d  %-10s  %3d %-40s\t%s" % [
    Fiber.current.object_id.to_s(16),
    $order,
    guess,
    fiber_idx,
    info,
    desc
  ]
  $order += 1
end

#
# Start reading in the eventmachine block below, then come back here
#

def get_result()
  ll(4, 'beg get_result',      " 6 fiber_1", "Beg get_result: this is called from within fiber_1")
  f = Fiber.current

  ll(4, 'setup callback',      " 7 fiber_1", "Pre 1.5s timer: set up some code to run 1.5s from now")
  EM.add_timer(1.5) do
    ll(5, 'beg callback',      "10 fiber_0", "Beg 1.5s timer: Executed *by the main fiber* 1.5 seconds from 'setup callback'; all non-deferred code from the EventMachine.run{} setup block has happened")

    ll(5, 'fiber.resume',      "11 fiber_0", "fiber.resume(:bob): picks up where the fiber left off ('ret = Fiber.yield'), giving it the value ':bob'")
    f.resume(:bob)

    ll(5, 'end callback',      "15 fiber_0", "End 1.5s timer: the callback is done, and so is the fiber, leaving only the EM.stop block on the reactor.")
  end

  ll(4, 'Fiber.yield',         " 8 fiber_1", "EM.add_timer just stashed away the 1.5s timer's block, so this runs next.")
  ret = Fiber.yield            #   fiber_1 -- Suspends action until fiber.resume called
  ll(4, "fiber result",        "12 fiber_1", "fiber result: '#{ret}' f.resume picks up here when the timer goes off.")

  ll(4, "end get_result",      "13 fiber_1", "end of function call")
  return ret
end


#
# Start here:
#
ll(0, 'beg main',              " 0 fiber_0", "top level")

EventMachine.run do
  ll(1, 'beg em setup',        " 1 fiber_0", "Eventmachine execution has begun; lines following this block aren't run until EM.stop is called")

  EM.add_timer(2.5){
    ll(2, "stop runner",       "17 fiber_0", "EM stop: 2.5s into the future, stop the Eventmachine reactor. The next to last thing in the program... ")
    EM.stop
  }

  ll(2, 'beg fiber setup',     " 2 fiber_0", "Pre fiber: the end-the-reactor block won't be called for 1.5s, so we get here immediately.")

  my_fiber = Fiber.new{
    ll(3, 'beg fiber',         " 5 fiber_1", "Beg fiber: runs when my_fiber.resume is called the first time. Am now in a new fiber.")

    res = get_result()        #    fiber1 -- get_result is called, but the last thing it does is pause execution

    ll(3, "got it: '#{res}'",  "14 fiber_1", "get_result returned '#{res}'")
    ll(3, "end fiber",         "15 fiber_1", "End fiber: picks up in timer callback, site of the last 'f.resume'")
  }

  ll(2, 'end fiber setup',     " 3 fiber_0", "nothing from inside the Fiber.new{} block has run yet.")

  ll(2, 'fiber.resume',        " 4 fiber_0", "first fiber.resume...")
  my_fiber.resume

  ll(1, 'end em setup',        " 9 fiber_0", "the line after my_fiber.resume, picks up when 'ret = Fiber.yield' is called. Now we go into the reactor loop and twiddle our thumbs for 1.5s")
end

ll(0, 'end main',              "18 fiber_0", "done.")

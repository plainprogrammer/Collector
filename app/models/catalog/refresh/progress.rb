# Writes a refresh run's progress while it works (spec 015 FR-1): at once when the stage changes, and otherwise at most
# once a second, as soon as 5,000 records were seen or 2 seconds passed since the last write (AC-2.9 asks for every
# 5,000 records or 5 seconds). How often it writes depends on work done and time, never on how many rows changed.
class Catalog::Refresh::Progress
  EVERY_RECORDS = 5_000
  EVERY_SECONDS = 2
  AT_MOST_EVERY_SECONDS = 1
  CLOCK = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }

  def initialize(run, counts, clock: CLOCK)
    @run = run
    @counts = counts
    @clock = clock
    @records = 0
    @written_at = -Float::INFINITY # nothing written yet: a report before any stage is due at once
  end

  # Enters a stage: written at once, so the page never shows the stage before.
  def stage(name)
    @stage = name
    @done = @total = nil
    write
  end

  # How far through the stage the source says it is (bytes received of the download, bytes read of the file).
  def at(done, total)
    @done = done
    @total = total
    write if due?
  end

  # One more record seen.
  def seen
    @records += 1
    write if due?
  end

  private
    def due?
      elapsed = @clock.call - @written_at
      elapsed >= AT_MOST_EVERY_SECONDS && (@records >= EVERY_RECORDS || elapsed >= EVERY_SECONDS)
    end

    def write
      @run.progress!(stage: @stage, done: @done, total: @total, counts: @counts)
      @records = 0
      @written_at = @clock.call
    end
end

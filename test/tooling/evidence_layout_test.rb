# frozen_string_literal: true

require "minitest/autorun"

# `evidence/` holds the repository's audit trail of verification that was actually performed - what
# was checked, how, what was observed, what was concluded. Whether a record is honest is a human
# question and no test can answer it. Its layout is not, and layout is the half that rots silently.
#
# Three rules, each failing in a way that is invisible until it is expensive:
#
# - Flat. The first `evidence/2026-q3/` looks tidy and quietly ends the one property the convention
#   exists for: `ls` is chronological, so a reader finds the most recent check on a subject without
#   knowing how anyone before them chose to file it.
# - `.md` only. Raw logs, screenshots, profiler output and coverage dumps are what an evidence
#   record is a summary OF. Committing them instead grows the repository without making anything
#   findable, and the measurement that mattered stays buried in a file nobody opens.
# - `YYYY-MM-DD-<topic>.md`. An ISO date is what makes lexicographic order chronological.
#   `sep-02-2026` sorts under "s", between two unrelated subjects.
#
# A missing `evidence/` directory passes. The convention is opt-in per repository, the directory
# appears on first real use, and an empty one would otherwise have to be held open by a `.gitkeep`
# that breaks the `.md` rule it exists to serve.
#
# Reads the filesystem rather than loading Rails, so it runs without a database or the compose
# environment.
class EvidenceLayoutTest < Minitest::Test
  REPOSITORY_ROOT = File.expand_path("../..", __dir__)
  EVIDENCE_DIR = File.join(REPOSITORY_ROOT, "evidence")

  # Anchored, and the month/day alternations are spelled out rather than \d{2}: `2026-13-45-x.md`
  # is exactly the kind of typo a lazier pattern lets through.
  EVIDENCE_NAME = /\A\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])-[a-z0-9]+(-[a-z0-9]+)*\.md\z/

  def entries
    return [] unless Dir.exist?(EVIDENCE_DIR)

    Dir.children(EVIDENCE_DIR).sort
  end

  def test_evidence_is_flat
    # File.directory? follows symlinks, which is what we want: a symlink to a directory is a
    # subdirectory for every purpose that matters here.
    subdirectories = entries.select { |name| File.directory?(File.join(EVIDENCE_DIR, name)) }

    assert_empty subdirectories, "evidence/ must be flat; no subdirectories"
  end

  def test_evidence_holds_only_markdown
    foreign =
      entries.reject { |name| File.directory?(File.join(EVIDENCE_DIR, name)) }
        .reject { |name| name.end_with?(".md") }

    assert_empty foreign,
                 "only .md files are allowed in evidence/; summarize the artifact in a record " \
                 "instead of committing it"
  end

  def test_evidence_records_are_named_by_iso_date
    misnamed =
      entries.select { |name| File.file?(File.join(EVIDENCE_DIR, name)) }
        .select { |name| name.end_with?(".md") }
        .grep_v(EVIDENCE_NAME)

    assert_empty misnamed, "expected evidence/YYYY-MM-DD-<topic>.md with a lowercase hyphenated topic"
  end
end

# frozen_string_literal: true

module DidYouMean
  # spell checker for a dictionary that has a tree
  # structure, see doc/tree_spell_checker_api.md
  class TreeSpellChecker
    attr_reader :dictionary, :dimensions, :separator, :augment

    def initialize(dictionary:, separator: '/', augment: nil)
      @dictionary = dictionary
      @separator = separator
      @augment = augment
    end

    def correct(input)
      plausibles = plausible_dimensions(input)
      return fall_back_to_normal_spell_check(input) if plausibles.empty?

      suggestions = find_suggestions(input, plausibles)
      return fall_back_to_normal_spell_check(input) if suggestions.empty?

      suggestions
    end

    def dictionary_without_leaves
      @dictionary_without_leaves ||= dictionary.map { |word| word.split(separator)[0..-2] }.uniq
    end

    def tree_depth
      @tree_depth ||= dictionary_without_leaves.max { |a, b| a.size <=> b.size }.size
    end

    def dimensions
      @dimensions ||= tree_depth.times.map do |index|
                        dictionary_without_leaves.map { |element| element[index] }.compact.uniq
                      end
    end

    private

    def find_suggestions(input, plausibles)
      states = plausibles[0].product(*plausibles[1..-1])
      paths = possible_paths(states)
      leaf = input.split(separator).last
      ideas = find_ideas(paths, leaf)
      ideas.compact.flatten
    end

    def fall_back_to_normal_spell_check(input)
      return [] unless augment

      ::DidYouMean::SpellChecker.new(dictionary: dictionary).correct(input)
    end

    def find_ideas(paths, leaf)
      paths.map do |path|
        names = find_leaves(path)
        ideas = correct_element(names, leaf)

        ideas_to_paths(ideas, leaf, names, path)
      end
    end

    def ideas_to_paths(ideas, leaf, names, path)
      return nil if ideas.empty?
      return [path + separator + leaf] if names.include?(leaf)

      ideas.map { |str| path + separator + str }
    end

    def find_leaves(path)
      dictionary.map do |str|
        next unless str.include?("#{path}#{separator}")

        str.gsub("#{path}#{separator}", '')
      end.compact
    end

    def possible_paths(states)
      states.map { |state| state.join(separator) }
    end

    def plausible_dimensions(input)
      elements = input.split(separator)[0..-2]
      elements.each_with_index.map do |element, i|
        next if dimensions[i].nil?

        correct_element(dimensions[i], element)
      end.compact
    end

    def correct_element(names, element)
      return names if names.size == 1

      str = normalize(element)

      return [str] if names.include?(str)

      ::DidYouMean::SpellChecker.new(dictionary: names).correct(str)
    end

    def normalize(leaf)
      str = leaf.dup
      str.downcase!
      return str unless str.include?('@')

      str.tr!('@', '  ')
    end
  end
end

require 'keg'
require 'formula'
require 'shellwords'

module BrewRmtree

  USAGE = <<-EOS.undent
  DESCRIPTION
    `rmtree` allows you to remove a formula entirely, including all of its dependencies,
    unless of course, they are used by another formula.

    Warning:

      Not all formulas declare their dependencies and therefore this command may end up
      removing something you still need. It should be used with caution.

  USAGE
    brew rmtree formula1 [formula2] [formula3]...

    Examples:

      brew rmtree gcc44 gcc48   # Removes 'gcc44' and 'gcc48' and their dependencies
  EOS

  module_function

  def bash(command)
    escaped_command = Shellwords.escape(command)
    return %x! bash -c #{escaped_command} !
  end

  def remove_keg(keg_name)
    # Remove old versions of keg
    puts bash "brew cleanup #{keg_name}"

    # Remove current keg
    puts bash "brew uninstall #{keg_name}"
  end

  def deps(keg_name)
    deps = bash "join <(brew leaves) <(brew deps #{keg_name})"
    deps.split("\n")
  end

  def reverse_deps(keg_name)
    reverse_deps = bash "brew uses --installed #{keg_name}"
    reverse_deps.split("\n")
  end

  def rmtree(keg_name)
    # Check if anything currently installed uses the keg
    reverse_deps = reverse_deps(keg_name)

    if reverse_deps.length > 0
      puts "Not removing #{keg_name} because other installed kegs depend on it:"
      puts reverse_deps.join("\n")
    else
      # Nothing claims to depend on it
      puts "Removing #{keg_name}..."
      remove_keg(keg_name)

      deps = deps(keg_name)
      if deps.length > 0
        puts "Found lingering dependencies:"
        puts deps.join("\n")

        deps.each do |dep|
          puts "Removing dependency #{dep}..."
          rmtree dep
        end
      else
        puts "No dependencies left on system for #{keg_name}."
      end
    end
  end

  def main
    if ARGV.size < 1 or ['-h', '?', '--help'].include? ARGV.first
      puts USAGE
      exit 0
    end

    if ARGV.force?
      puts "--force is not supported."
      exit 1
    end

    raise KegUnspecifiedError if ARGV.named.empty?

    ARGV.named.each { |keg_name| rmtree keg_name }
  end
end

BrewRmtree.main
exit 0

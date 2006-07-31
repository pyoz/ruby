
require "delegate"

# Weak Reference class that does not bother GCing.  This allows the
# referenced object to be garbage collected as if nothing else is
# referring to it.  Because Weakref inherits from Delegator it passes
# method calls to the object from which it was constructed, so it
# is of the same Duck Type.
#
# Usage:
#   foo = Object.new
#   foo = Object.new
#   p foo.to_s			# original's class
#   foo = WeakRef.new(foo)
#   p foo.to_s			# should be same class
#   ObjectSpace.garbage_collect
#   p foo.to_s			# should raise exception (recycled)
class WeakRef<Delegator

  # RefError is raised if an object cannot be referenced by a WeakRef.
  class RefError<StandardError
  end

  @@id_map =  {}                # obj -> [ref,...]
  @@id_rev_map =  {}            # ref -> obj
  @@final = lambda{|id|
    __old_status = Thread.critical
    Thread.critical = true
    begin
      rids = @@id_map[id]
      if rids
	for rid in rids
	  @@id_rev_map.delete(rid)
	end
	@@id_map.delete(id)
      end
      rid = @@id_rev_map[id]
      if rid
	@@id_rev_map.delete(id)
	@@id_map[rid].delete(id)
	@@id_map.delete(rid) if @@id_map[rid].empty?
      end
    ensure
      Thread.critical = __old_status
    end
  }

  # Create a new WeakRef from +orig+.
  def initialize(orig)
    super
    @__id = orig.__id__
    ObjectSpace.define_finalizer orig, @@final
    ObjectSpace.define_finalizer self, @@final
    __old_status = Thread.critical
    begin
      Thread.critical = true
      @@id_map[@__id] = [] unless @@id_map[@__id]
    ensure
      Thread.critical = __old_status
    end
    @@id_map[@__id].push self.__id__
    @@id_rev_map[self.__id__] = @__id
  end

  # Return the object this WeakRef references. Raise
  # RefError if this is impossible.  The object is that
  # to which method calls are delegated (see Delegator).
  def __getobj__
    unless @@id_rev_map[self.__id__] == @__id
      raise RefError, "Illegal Reference - probably recycled", caller(2)
    end
    begin
      ObjectSpace._id2ref(@__id)
    rescue RangeError
      raise RefError, "Illegal Reference - probably recycled", caller(2)
    end
  end

  # Determine if this Weakref still refers to anything.
  def weakref_alive?
    @@id_rev_map[self.__id__] == @__id
  end
end

if __FILE__ == $0
  require 'thread'
  foo = Object.new
  p foo.to_s			# original's class
  foo = WeakRef.new(foo)
  p foo.to_s			# should be same class
  ObjectSpace.garbage_collect
  p foo.to_s			# should raise exception (recycled)
end

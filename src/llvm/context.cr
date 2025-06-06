class LLVM::Context
  def self.new
    new(LibLLVM.create_context)
  end

  def initialize(@unwrap : LibLLVM::ContextRef, @dispose_on_finalize = true)
    @disposed = false
    @builders = [] of LLVM::Builder
  end

  def new_module(name : String) : Module
    Module.new(LibLLVM.module_create_with_name_in_context(name, self), self)
  end

  def new_builder : Builder
    # builder = Builder.new(LibLLVM.create_builder_in_context(self), self)
    builder = Builder.new(LibLLVM.create_builder_in_context(self))
    @builders << builder
    builder
  end

  def void : Type
    Type.new LibLLVM.void_type_in_context(self)
  end

  def int1 : Type
    Type.new LibLLVM.int1_type_in_context(self)
  end

  def int8 : Type
    Type.new LibLLVM.int8_type_in_context(self)
  end

  def int16 : Type
    Type.new LibLLVM.int16_type_in_context(self)
  end

  def int32 : Type
    Type.new LibLLVM.int32_type_in_context(self)
  end

  def int64 : Type
    Type.new LibLLVM.int64_type_in_context(self)
  end

  def int128 : Type
    Type.new LibLLVM.int128_type_in_context(self)
  end

  def int(bits : Int) : Type
    Type.new LibLLVM.int_type_in_context(self, bits)
  end

  def half : Type
    Type.new LibLLVM.half_type_in_context(self)
  end

  def float : Type
    Type.new LibLLVM.float_type_in_context(self)
  end

  def double : Type
    Type.new LibLLVM.double_type_in_context(self)
  end

  def x86_fp80 : Type
    Type.new LibLLVM.x86_fp80_type_in_context(self)
  end

  def fp128 : Type
    Type.new LibLLVM.fp128_type_in_context(self)
  end

  def ppc_fp128 : Type
    Type.new LibLLVM.ppc_fp128_type_in_context(self)
  end

  def pointer(address_space = 0) : Type
    {% if LibLLVM::IS_LT_150 %}
      {% raise "Opaque pointers are only supported on LLVM 15.0 or above" %}
    {% else %}
      Type.new LibLLVM.pointer_type_in_context(self, address_space)
    {% end %}
  end

  def void_pointer(address_space = 0) : Type
    {% if LibLLVM::IS_LT_150 %}
      int8.pointer(address_space)
    {% else %}
      pointer(address_space)
    {% end %}
  end

  def struct(name : String, packed = false, &) : Type
    llvm_struct = LibLLVM.struct_create_named(self, name)
    the_struct = Type.new llvm_struct
    element_types = (yield the_struct).as(Array(LLVM::Type))
    LibLLVM.struct_set_body(llvm_struct, (element_types.to_unsafe.as(LibLLVM::TypeRef*)), element_types.size, packed ? 1 : 0)
    the_struct
  end

  def struct(element_types : Array(LLVM::Type), name = nil, packed = false) : Type
    if name
      self.struct(name, packed) { element_types }
    else
      Type.new LibLLVM.struct_type_in_context(self, (element_types.to_unsafe.as(LibLLVM::TypeRef*)), element_types.size, packed ? 1 : 0)
    end
  end

  def const_string(string : String) : Value
    const_bytes(string.unsafe_byte_slice(0, string.bytesize + 1))
  end

  def const_bytes(bytes : Bytes) : Value
    {% if LibLLVM::IS_LT_190 %}
      Value.new LibLLVM.const_string_in_context(self, bytes, bytes.size, 1)
    {% else %}
      Value.new LibLLVM.const_string_in_context2(self, bytes, bytes.size, 1)
    {% end %}
  end

  def const_struct(values : Array(LLVM::Value), packed = false) : Value
    Value.new LibLLVM.const_struct_in_context(self, (values.to_unsafe.as(LibLLVM::ValueRef*)), values.size, packed ? 1 : 0)
  end

  def md_string(value : String) : Value
    LLVM::Value.new LibLLVM.md_string_in_context2(self, value, value.bytesize)
  end

  def md_node(values : Array(Value)) : Value
    Value.new LibLLVM.md_node_in_context2(self, (values.to_unsafe.as(LibLLVM::ValueRef*)), values.size)
  end

  def parse_ir(buf : MemoryBuffer)
    ret = LibLLVM.parse_ir_in_context(self, buf, out mod, out msg)
    if ret != 0 && msg
      raise LLVM.string_and_dispose(msg)
    end
    Module.new(mod, self)
  end

  def ==(other : self)
    @unwrap == other.@unwrap
  end

  def to_unsafe
    @unwrap
  end

  def finalize
    return unless @dispose_on_finalize
    return if @disposed
    @disposed = true

    @builders.each &.dispose

    LibLLVM.dispose_context(self)
  end

  # The next lines are for ease debugging when a types/values
  # are incorrectly used across contexts.

  # @@info = {} of UInt64 => String

  # def self.register(context : Context, name : String)
  #   @@info[context.@unwrap.address] = name
  # end

  # def self.lookup(context : Context)
  #   @@info[context.@unwrap.address]? || "global"
  # end

  # def self.wrong(expected, got, msg)
  #   raise "#{msg} (expected #{lookup(expected)}, got #{lookup(got)})"
  # end
end

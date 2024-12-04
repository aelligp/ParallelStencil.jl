using Test
using CellArrays, StaticArrays
import ParallelStencil
using ParallelStencil.ParallelKernel
import ParallelStencil.ParallelKernel: @reset_parallel_kernel, @is_initialized, @get_numbertype, NUMBERTYPE_NONE, SUPPORTED_PACKAGES, PKG_CUDA, PKG_AMDGPU, PKG_METAL, PKG_POLYESTER
import ParallelStencil.ParallelKernel: @require, @prettystring, @gorgeousstring, interpolate
import ParallelStencil.ParallelKernel: checkargs_CellType, _CellType
using ParallelStencil.ParallelKernel.FieldAllocators
import ParallelStencil.ParallelKernel.FieldAllocators: checksargs_field_macros, checkargs_allocate
using ParallelStencil.ParallelKernel.Exceptions
TEST_PACKAGES = SUPPORTED_PACKAGES
@static if PKG_CUDA in TEST_PACKAGES
    import CUDA
    if !CUDA.functional() TEST_PACKAGES = filter!(x->x≠PKG_CUDA, TEST_PACKAGES) end
    @define_CuCellArray
end
@static if PKG_AMDGPU in TEST_PACKAGES
    import AMDGPU
    if !AMDGPU.functional() TEST_PACKAGES = filter!(x->x≠PKG_AMDGPU, TEST_PACKAGES) end
    @define_ROCCellArray
end
@static if PKG_METAL in TEST_PACKAGES
    import Metal
    if !Metal.functional() TEST_PACKAGES = filter!(x->x≠PKG_METAL, TEST_PACKAGES) end
    @define_MtlCellArray
end
@static if PKG_POLYESTER in TEST_PACKAGES
    import Polyester
end
Base.retry_load_extensions() # Potentially needed to load the extensions after the packages have been filtered.
const DATA_INDEX = ParallelStencil.INT_THREADS # TODO: using Data.Index does not work in combination with @reset_parallel_kernel, because the macros from module Test alternate the order of evaluation, resulting in the Data module being replaced with an empty module before Data.Index is evaluated. If at some point the indexing varies depending on the used package, then something more sophisticated is needed here (e.g., wrapping the test for each package in a module and using then Data.Index everywhere).


@static for package in TEST_PACKAGES

eval(:(
    @testset "$(basename(@__FILE__)) (package: $(nameof($package)))" begin
        @testset "1. @CellType macro" begin
            @require !@is_initialized()
            @init_parallel_kernel($package, Float16)
            @require @is_initialized()
            @testset "fieldnames" begin
                call = @prettystring(1, @CellType SymmetricTensor2D fieldnames=(xx, zz, xz))
                @test occursin("struct SymmetricTensor2D <: ParallelStencil.ParallelKernel.FieldArray{Tuple{3}, Float16, length([3])}", call)
                @test occursin("xx::Float16", call)
                @test occursin("zz::Float16", call)
                @test occursin("xz::Float16", call)
                call = @prettystring(1, @CellType SymmetricTensor3D fieldnames=(xx, yy, zz, yz, xz, xy))
                @test occursin("struct SymmetricTensor3D <: ParallelStencil.ParallelKernel.FieldArray{Tuple{6}, Float16, length([6])}", call)
                @test occursin("xx::Float16", call)
                @test occursin("yy::Float16", call)
                @test occursin("zz::Float16", call)
                @test occursin("yz::Float16", call)
                @test occursin("xz::Float16", call)
                @test occursin("xy::Float16", call)
            end;
            @testset "dims" begin
                call = @prettystring(1, @CellType Tensor2D fieldnames=(xxxx, yxxx, xyxx, yyxx, xxyx, yxyx, xyyx, yyyx, xxxy, yxxy, xyxy, yyxy, xxyy, yxyy, xyyy, yyyy) dims=(2,2,2,2))
                @test occursin("struct Tensor2D <: ParallelStencil.ParallelKernel.FieldArray{Tuple{2, 2, 2, 2}, Float16, length(Any[2, 2, 2, 2])}", call)
                @test occursin("xxxx::Float16", call)
                @test occursin("yxxx::Float16", call)
                @test occursin("xyxx::Float16", call)
                @test occursin("yyxx::Float16", call)
                @test occursin("xxyx::Float16", call)
                @test occursin("yxyx::Float16", call)
                @test occursin("xyyx::Float16", call)
                @test occursin("yyyx::Float16", call)
                @test occursin("xxxy::Float16", call)
                @test occursin("yxxy::Float16", call)
                @test occursin("xyxy::Float16", call)
                @test occursin("yyxy::Float16", call)
                @test occursin("xxyy::Float16", call)
                @test occursin("yxyy::Float16", call)
                @test occursin("xyyy::Float16", call)
                @test occursin("yyyy::Float16", call)
            end;
            @testset "parametric" begin
                call = @prettystring(1, @CellType SymmetricTensor2D fieldnames=(xx, zz, xz) parametric=true)
                @test occursin("struct SymmetricTensor2D{T} <: ParallelStencil.ParallelKernel.FieldArray{Tuple{3}, T, length([3])}", call)
                @test occursin("xx::T", call)
                @test occursin("zz::T", call)
                @test occursin("xz::T", call)
            end;
            @testset "eltype" begin
                call = @prettystring(1, @CellType SymmetricTensor2D fieldnames=(xx, zz, xz) eltype=Float32)
                @test occursin("struct SymmetricTensor2D <: ParallelStencil.ParallelKernel.FieldArray{Tuple{3}, Float32, length([3])}", call)
                @test occursin("xx::Float32", call)
                @test occursin("zz::Float32", call)
                @test occursin("xz::Float32", call)
                call = @prettystring(1, @CellType SymmetricTensor2D_Index fieldnames=(xx, zz, xz) eltype=Data.Index)
                @test occursin("struct SymmetricTensor2D_Index <: ParallelStencil.ParallelKernel.FieldArray{Tuple{3}, Data.Index, length([3])}", call)
                @test occursin("xx::Data.Index", call)
                @test occursin("zz::Data.Index", call)
                @test occursin("xz::Data.Index", call)
            end;
            @reset_parallel_kernel()
        end;
        @testset "2. allocator macros (with default numbertype)" begin
            @require !@is_initialized()
            @init_parallel_kernel($package, Float16)
            @require @is_initialized()
            @testset "datatype definitions" begin
                @CellType SymmetricTensor2D fieldnames=(xx, zz, xz)
                @CellType SymmetricTensor3D fieldnames=(xx, yy, zz, yz, xz, xy)
                @CellType Tensor2D fieldnames=(xxxx, yxxx, xyxx, yyxx, xxyx, yxyx, xyyx, yyyx, xxxy, yxxy, xyxy, yyxy, xxyy, yxyy, xyyy, yyyy) dims=(2,2,2,2)
                @CellType SymmetricTensor2D_T fieldnames=(xx, zz, xz) parametric=true
                @CellType SymmetricTensor2D_Float32 fieldnames=(xx, zz, xz) eltype=Float32
                @CellType SymmetricTensor2D_Bool fieldnames=(xx, zz, xz) eltype=Bool
                @CellType SymmetricTensor2D_Index fieldnames=(xx, zz, xz) eltype=DATA_INDEX
                @test SymmetricTensor2D <: FieldArray
                @test SymmetricTensor3D <: FieldArray
                @test Tensor2D <: FieldArray
                @test SymmetricTensor2D_T <: FieldArray
                @test SymmetricTensor2D_Float32 <: FieldArray
                @test SymmetricTensor2D_Bool <: FieldArray
                @test SymmetricTensor2D_Index <: FieldArray
            end;
            @testset "mapping to package (no celldims/celltype)" begin
                @static if $package == $PKG_CUDA
                    @test typeof(@zeros(2,3))                      == typeof(CUDA.CuArray(zeros(Float16,2,3)))
                    @test typeof(@zeros(2,3, eltype=Float32))      == typeof(CUDA.CuArray(zeros(Float32,2,3)))
                    @test typeof(@zeros(2,3, eltype=DATA_INDEX))   == typeof(CUDA.CuArray(zeros(DATA_INDEX,2,3)))
                    @test typeof(@ones(2,3))                       == typeof(CUDA.CuArray(ones(Float16,2,3)))
                    @test typeof(@ones(2,3, eltype=Float32))       == typeof(CUDA.CuArray(ones(Float32,2,3)))
                    @test typeof(@ones(2,3, eltype=DATA_INDEX))    == typeof(CUDA.CuArray(ones(DATA_INDEX,2,3)))
                    @test typeof(@rand(2,3))                       == typeof(CUDA.CuArray(rand(Float16,2,3)))
                    @test typeof(@rand(2,3, eltype=Float64))       == typeof(CUDA.CuArray(rand(Float64,2,3)))
                    @test typeof(@rand(2,3, eltype=DATA_INDEX))    == typeof(CUDA.CuArray(rand(DATA_INDEX,2,3)))
                    @test typeof(@fill(9, 2,3))                    == typeof(CUDA.CuArray(fill(convert(Float16, 9), 2,3)))
                    @test typeof(@fill(9, 2,3, eltype=Float64))    == typeof(CUDA.CuArray(fill(convert(Float64, 9), 2,3)))
                    @test typeof(@fill(9, 2,3, eltype=DATA_INDEX)) == typeof(CUDA.CuArray(fill(convert(DATA_INDEX, 9), 2,3)))
                elseif $package == $PKG_AMDGPU
                    @test typeof(@zeros(2,3))                      == typeof(AMDGPU.ROCArray(zeros(Float16,2,3)))
                    @test typeof(@zeros(2,3, eltype=Float32))      == typeof(AMDGPU.ROCArray(zeros(Float32,2,3)))
                    @test typeof(@zeros(2,3, eltype=DATA_INDEX))   == typeof(AMDGPU.ROCArray(zeros(DATA_INDEX,2,3)))
                    @test typeof(@ones(2,3))                       == typeof(AMDGPU.ROCArray(ones(Float16,2,3)))
                    @test typeof(@ones(2,3, eltype=Float32))       == typeof(AMDGPU.ROCArray(ones(Float32,2,3)))
                    @test typeof(@ones(2,3, eltype=DATA_INDEX))    == typeof(AMDGPU.ROCArray(ones(DATA_INDEX,2,3)))
                    @test typeof(@rand(2,3))                       == typeof(AMDGPU.ROCArray(rand(Float16,2,3)))
                    @test typeof(@rand(2,3, eltype=Float64))       == typeof(AMDGPU.ROCArray(rand(Float64,2,3)))
                    @test typeof(@rand(2,3, eltype=DATA_INDEX))    == typeof(AMDGPU.ROCArray(rand(DATA_INDEX,2,3)))
                    @test typeof(@fill(9, 2,3))                    == typeof(AMDGPU.ROCArray(fill(convert(Float16, 9), 2,3)))
                    @test typeof(@fill(9, 2,3, eltype=Float64))    == typeof(AMDGPU.ROCArray(fill(convert(Float64, 9), 2,3)))
                    @test typeof(@fill(9, 2,3, eltype=DATA_INDEX)) == typeof(AMDGPU.ROCArray(fill(convert(DATA_INDEX, 9), 2,3)))
                elseif $package == $PKG_METAL
                    @test typeof(@zeros(2,3))                      == typeof(Metal.MtlArray(zeros(Float16,2,3)))
                    @test typeof(@zeros(2,3, eltype=Float32))      == typeof(Metal.MtlArray(zeros(Float32,2,3)))
                    @test typeof(@zeros(2,3, eltype=DATA_INDEX))   == typeof(Metal.MtlArray(zeros(DATA_INDEX,2,3)))
                    @test typeof(@ones(2,3))                       == typeof(Metal.MtlArray(ones(Float16,2,3)))
                    @test typeof(@ones(2,3, eltype=Float32))       == typeof(Metal.MtlArray(ones(Float32,2,3)))
                    @test typeof(@ones(2,3, eltype=DATA_INDEX))    == typeof(Metal.MtlArray(ones(DATA_INDEX,2,3)))
                    @test typeof(@rand(2,3))                       == typeof(Metal.MtlArray(rand(Float16,2,3)))
                    @test typeof(@rand(2,3, eltype=Float32))       == typeof(Metal.MtlArray(rand(Float32,2,3)))
                    @test typeof(@rand(2,3, eltype=DATA_INDEX))    == typeof(Metal.MtlArray(rand(DATA_INDEX,2,3)))
                    @test typeof(@fill(9, 2,3))                    == typeof(Metal.MtlArray(fill(convert(Float16, 9), 2,3)))
                    @test typeof(@fill(9, 2,3, eltype=Float32))    == typeof(Metal.MtlArray(fill(convert(Float32, 9), 2,3)))
                    @test typeof(@fill(9, 2,3, eltype=DATA_INDEX)) == typeof(Metal.MtlArray(fill(convert(DATA_INDEX, 9), 2,3)))
                else
                    @test typeof(@zeros(2,3))                      == typeof(parentmodule($package).zeros(Float16,2,3))
                    @test typeof(@zeros(2,3, eltype=Float32))      == typeof(parentmodule($package).zeros(Float32,2,3))
                    @test typeof(@zeros(2,3, eltype=DATA_INDEX))   == typeof(parentmodule($package).zeros(DATA_INDEX,2,3))
                    @test typeof(@ones(2,3))                       == typeof(parentmodule($package).ones(Float16,2,3))
                    @test typeof(@ones(2,3, eltype=Float32))       == typeof(parentmodule($package).ones(Float32,2,3))
                    @test typeof(@ones(2,3, eltype=DATA_INDEX))    == typeof(parentmodule($package).ones(DATA_INDEX,2,3))
                    @test typeof(@rand(2,3))                       == typeof(parentmodule($package).rand(Float16,2,3))
                    @test typeof(@rand(2,3, eltype=Float64))       == typeof(parentmodule($package).rand(Float64,2,3))
                    @test typeof(@rand(2,3, eltype=DATA_INDEX))    == typeof(parentmodule($package).rand(DATA_INDEX,2,3))
                    @test typeof(@fill(9, 2,3))                    == typeof(fill(convert(Float16, 9), 2,3))
                    @test typeof(@fill(9, 2,3, eltype=Float64))    == typeof(fill(convert(Float64, 9), 2,3))
                    @test typeof(@fill(9, 2,3, eltype=DATA_INDEX)) == typeof(fill(convert(DATA_INDEX, 9), 2,3))
                end
                @test Array(@falses(2,3)) == Array(parentmodule($package).falses(2,3))
                @test Array(@trues(2,3))  == Array(parentmodule($package).trues(2,3))
            end;
            @testset "mapping to package (with celldims)" begin
                T_Float16 = SMatrix{(3,4)..., Float16,    prod((3,4))}
                T_Float32 = SMatrix{(3,4)..., Float32,    prod((3,4))}
                T_Float64 = SMatrix{(3,4)..., Float64,    prod((3,4))}
                T_Bool    = SMatrix{(3,4)..., Bool,       prod((3,4))}
                T_Index   = SMatrix{(3,4)..., DATA_INDEX, prod((3,4))}
                @static if $package == $PKG_CUDA
                    CUDA.allowscalar(true)
                    @test @zeros(2,3, celldims=(3,4))                           == CellArrays.fill!(CuCellArray{T_Float16}(undef,2,3), T_Float16(zeros((3,4))))
                    @test @zeros(2,3, celldims=(3,4), eltype=Float32)           == CellArrays.fill!(CuCellArray{T_Float32}(undef,2,3), T_Float32(zeros((3,4))))
                    @test @ones(2,3, celldims=(3,4))                            == CellArrays.fill!(CuCellArray{T_Float16}(undef,2,3), T_Float16(ones((3,4))))
                    @test @ones(2,3, celldims=(3,4), eltype=Float32)            == CellArrays.fill!(CuCellArray{T_Float32}(undef,2,3), T_Float32(ones((3,4))))
                    @test typeof(@rand(2,3, celldims=(3,4)))                    == typeof(CuCellArray{T_Float16,0}(undef,2,3))
                    @test typeof(@rand(2,3, celldims=(3,4), eltype=Float64))    == typeof(CuCellArray{T_Float64,0}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4)))                 == typeof(CuCellArray{T_Float16,0}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4), eltype=Float64)) == typeof(CuCellArray{T_Float64,0}(undef,2,3))
                    @test @falses(2,3, celldims=(3,4))                          == CellArrays.fill!(CuCellArray{T_Bool}(undef,2,3), falses((3,4)))
                    @test @trues(2,3, celldims=(3,4))                           == CellArrays.fill!(CuCellArray{T_Bool}(undef,2,3), trues((3,4)))
                    @test @zeros(2,3, celldims=(3,4), eltype=DATA_INDEX)        == CellArrays.fill!(CuCellArray{T_Index}(undef,2,3), T_Index(zeros((3,4))))
                    CUDA.allowscalar(false)
                elseif $package == $PKG_AMDGPU
                    AMDGPU.allowscalar(true) #TODO: check how to do (everywhere) (for GPU, CellArray B is the same - could potentially be merged if not using type alias...)
                    @test @zeros(2,3, celldims=(3,4))                           == CellArrays.fill!(ROCCellArray{T_Float16}(undef,2,3), T_Float16(zeros((3,4))))
                    @test @zeros(2,3, celldims=(3,4), eltype=Float32)           == CellArrays.fill!(ROCCellArray{T_Float32}(undef,2,3), T_Float32(zeros((3,4))))
                    @test @ones(2,3, celldims=(3,4))                            == CellArrays.fill!(ROCCellArray{T_Float16}(undef,2,3), T_Float16(ones((3,4))))
                    @test @ones(2,3, celldims=(3,4), eltype=Float32)            == CellArrays.fill!(ROCCellArray{T_Float32}(undef,2,3), T_Float32(ones((3,4))))
                    @test typeof(@rand(2,3, celldims=(3,4)))                    == typeof(ROCCellArray{T_Float16,0}(undef,2,3))
                    @test typeof(@rand(2,3, celldims=(3,4), eltype=Float64))    == typeof(ROCCellArray{T_Float64,0}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4)))                 == typeof(ROCCellArray{T_Float16,0}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4), eltype=Float64)) == typeof(ROCCellArray{T_Float64,0}(undef,2,3))
                    @test @falses(2,3, celldims=(3,4))                          == CellArrays.fill!(ROCCellArray{T_Bool}(undef,2,3), falses((3,4)))
                    @test @trues(2,3, celldims=(3,4))                           == CellArrays.fill!(ROCCellArray{T_Bool}(undef,2,3), trues((3,4)))
                    @test @zeros(2,3, celldims=(3,4), eltype=DATA_INDEX)        == CellArrays.fill!(ROCCellArray{T_Index}(undef,2,3), T_Index(zeros((3,4))))
                    AMDGPU.allowscalar(false) #TODO: check how to do
                elseif $package == $PKG_METAL
                    Metal.allowscalar(true)
                    @test @zeros(2,3, celldims=(3,4))                           == CellArrays.fill!(MtlCellArray{T_Float16}(undef,2,3), T_Float16(zeros((3,4))))
                    @test @zeros(2,3, celldims=(3,4), eltype=Float32)           == CellArrays.fill!(MtlCellArray{T_Float32}(undef,2,3), T_Float32(zeros((3,4))))
                    @test @ones(2,3, celldims=(3,4))                            == CellArrays.fill!(MtlCellArray{T_Float16}(undef,2,3), T_Float16(ones((3,4))))
                    @test @ones(2,3, celldims=(3,4), eltype=Float32)            == CellArrays.fill!(MtlCellArray{T_Float32}(undef,2,3), T_Float32(ones((3,4))))
                    @test typeof(@rand(2,3, celldims=(3,4)))                    == typeof(MtlCellArray{T_Float16,0}(undef,2,3))
                    @test typeof(@rand(2,3, celldims=(3,4), eltype=Float32))    == typeof(MtlCellArray{T_Float32,0}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4)))                 == typeof(MtlCellArray{T_Float16,0}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4), eltype=Float32)) == typeof(MtlCellArray{T_Float32,0}(undef,2,3))
                    @test @falses(2,3, celldims=(3,4))                          == CellArrays.fill!(MtlCellArray{T_Bool}(undef,2,3), falses((3,4)))
                    @test @trues(2,3, celldims=(3,4))                           == CellArrays.fill!(MtlCellArray{T_Bool}(undef,2,3), trues((3,4)))
                    @test @zeros(2,3, celldims=(3,4), eltype=DATA_INDEX)        == CellArrays.fill!(MtlCellArray{T_Index}(undef,2,3), T_Index(zeros((3,4))))
                    Metal.allowscalar(false)
                else
                    @test @zeros(2,3, celldims=(3,4))                           == CellArrays.fill!(CPUCellArray{T_Float16}(undef,2,3), T_Float16(zeros((3,4))))
                    @test @zeros(2,3, celldims=(3,4), eltype=Float32)           == CellArrays.fill!(CPUCellArray{T_Float32}(undef,2,3), T_Float32(zeros((3,4))))
                    @test @ones(2,3, celldims=(3,4))                            == CellArrays.fill!(CPUCellArray{T_Float16}(undef,2,3), T_Float16(ones((3,4))))
                    @test @ones(2,3, celldims=(3,4), eltype=Float32)            == CellArrays.fill!(CPUCellArray{T_Float32}(undef,2,3), T_Float32(ones((3,4))))
                    @test typeof(@rand(2,3, celldims=(3,4)))                    == typeof(CPUCellArray{T_Float16,1}(undef,2,3))
                    @test typeof(@rand(2,3, celldims=(3,4), eltype=Float64))    == typeof(CPUCellArray{T_Float64,1}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4)))                 == typeof(CPUCellArray{T_Float16,1}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4), eltype=Float64)) == typeof(CPUCellArray{T_Float64,1}(undef,2,3))
                    @test @falses(2,3, celldims=(3,4))                          == CellArrays.fill!(CPUCellArray{T_Bool}(undef,2,3), falses((3,4)))
                    @test @trues(2,3, celldims=(3,4))                           == CellArrays.fill!(CPUCellArray{T_Bool}(undef,2,3), trues((3,4)))
                    @test @zeros(2,3, celldims=(3,4), eltype=DATA_INDEX)        == CellArrays.fill!(CPUCellArray{T_Index}(undef,2,3), T_Index(zeros((3,4))))
                end
            end;
            @testset "mapping to package (with celltype)" begin
                @static if $package == $PKG_CUDA
                    CUDA.allowscalar(true)
                    @test @zeros(2,3, celltype=SymmetricTensor2D)               == CellArrays.fill!(CuCellArray{SymmetricTensor2D}(undef,2,3), SymmetricTensor2D(zeros(3)))
                    @test @zeros(2,3, celltype=SymmetricTensor3D)               == CellArrays.fill!(CuCellArray{SymmetricTensor3D}(undef,2,3), SymmetricTensor3D(zeros(6)))
                    @test @zeros(2,3, celltype=Tensor2D)                        == CellArrays.fill!(CuCellArray{Tensor2D}(undef,2,3), Tensor2D(zeros((2,2,2,2))))
                    @test @zeros(2,3, celltype=SymmetricTensor2D_T{Float64})    == CellArrays.fill!(CuCellArray{SymmetricTensor2D_T{Float64}}(undef,2,3), SymmetricTensor2D_T{Float64}(zeros(3)))
                    @test @zeros(2,3, celltype=SymmetricTensor2D_Float32)       == CellArrays.fill!(CuCellArray{SymmetricTensor2D_Float32}(undef,2,3), SymmetricTensor2D_Float32(zeros(3)))
                    @test @ones(2,3, celltype=SymmetricTensor2D)                == CellArrays.fill!(CuCellArray{SymmetricTensor2D}(undef,2,3), SymmetricTensor2D(ones(3)))
                    @test typeof(@rand(2,3, celltype=SymmetricTensor2D))        == typeof(CuCellArray{SymmetricTensor2D,0}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celltype=SymmetricTensor2D))     == typeof(CuCellArray{SymmetricTensor2D,0}(undef,2,3))
                    @test @zeros(2,3, celltype=SymmetricTensor2D_Index)         == CellArrays.fill!(CuCellArray{SymmetricTensor2D_Index}(undef,2,3), SymmetricTensor2D_Index(zeros(3)))
                    CUDA.allowscalar(false)
                elseif $package == $PKG_AMDGPU
                    AMDGPU.allowscalar(true)
                    @test @zeros(2,3, celltype=SymmetricTensor2D)               == CellArrays.fill!(ROCCellArray{SymmetricTensor2D}(undef,2,3), SymmetricTensor2D(zeros(3)))
                    @test @zeros(2,3, celltype=SymmetricTensor3D)               == CellArrays.fill!(ROCCellArray{SymmetricTensor3D}(undef,2,3), SymmetricTensor3D(zeros(6)))
                    @test @zeros(2,3, celltype=Tensor2D)                        == CellArrays.fill!(ROCCellArray{Tensor2D}(undef,2,3), Tensor2D(zeros((2,2,2,2))))
                    @test @zeros(2,3, celltype=SymmetricTensor2D_T{Float64})    == CellArrays.fill!(ROCCellArray{SymmetricTensor2D_T{Float64}}(undef,2,3), SymmetricTensor2D_T{Float64}(zeros(3)))
                    @test @zeros(2,3, celltype=SymmetricTensor2D_Float32)       == CellArrays.fill!(ROCCellArray{SymmetricTensor2D_Float32}(undef,2,3), SymmetricTensor2D_Float32(zeros(3)))
                    @test @ones(2,3, celltype=SymmetricTensor2D)                == CellArrays.fill!(ROCCellArray{SymmetricTensor2D}(undef,2,3), SymmetricTensor2D(ones(3)))
                    @test typeof(@rand(2,3, celltype=SymmetricTensor2D))        == typeof(ROCCellArray{SymmetricTensor2D,0}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celltype=SymmetricTensor2D))     == typeof(ROCCellArray{SymmetricTensor2D,0}(undef,2,3))
                    @test @zeros(2,3, celltype=SymmetricTensor2D_Index)         == CellArrays.fill!(ROCCellArray{SymmetricTensor2D_Index}(undef,2,3), SymmetricTensor2D_Index(zeros(3)))
                    AMDGPU.allowscalar(false)
                elseif $package == $PKG_METAL
                    Metal.allowscalar(true)
                    @test @zeros(2,3, celltype=SymmetricTensor2D)               == CellArrays.fill!(MtlCellArray{SymmetricTensor2D}(undef,2,3), SymmetricTensor2D(zeros(3)))
                    @test @zeros(2,3, celltype=SymmetricTensor3D)               == CellArrays.fill!(MtlCellArray{SymmetricTensor3D}(undef,2,3), SymmetricTensor3D(zeros(6)))
                    @test @zeros(2,3, celltype=Tensor2D)                        == CellArrays.fill!(MtlCellArray{Tensor2D}(undef,2,3), Tensor2D(zeros((2,2,2,2))))
                    @test @zeros(2,3, celltype=SymmetricTensor2D_T{Float32})    == CellArrays.fill!(MtlCellArray{SymmetricTensor2D_T{Float32}}(undef,2,3), SymmetricTensor2D_T{Float64}(zeros(3)))
                    @test @zeros(2,3, celltype=SymmetricTensor2D_Float32)       == CellArrays.fill!(MtlCellArray{SymmetricTensor2D_Float32}(undef,2,3), SymmetricTensor2D_Float32(zeros(3)))
                    @test @ones(2,3, celltype=SymmetricTensor2D)                == CellArrays.fill!(MtlCellArray{SymmetricTensor2D}(undef,2,3), SymmetricTensor2D(ones(3)))
                    @test typeof(@rand(2,3, celltype=SymmetricTensor2D))        == typeof(MtlCellArray{SymmetricTensor2D,0}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celltype=SymmetricTensor2D))     == typeof(MtlCellArray{SymmetricTensor2D,0}(undef,2,3))
                    @test @zeros(2,3, celltype=SymmetricTensor2D_Index)         == CellArrays.fill!(MtlCellArray{SymmetricTensor2D_Index}(undef,2,3), SymmetricTensor2D_Index(zeros(3)))
                    Metal.allowscalar(false)
                else
                    @test @zeros(2,3, celltype=SymmetricTensor2D)               == CellArrays.fill!(CPUCellArray{SymmetricTensor2D}(undef,2,3), SymmetricTensor2D(zeros(3)))
                    @test @zeros(2,3, celltype=SymmetricTensor3D)               == CellArrays.fill!(CPUCellArray{SymmetricTensor3D}(undef,2,3), SymmetricTensor3D(zeros(6)))
                    @test @zeros(2,3, celltype=Tensor2D)                        == CellArrays.fill!(CPUCellArray{Tensor2D}(undef,2,3), Tensor2D(zeros((2,2,2,2))))
                    @test @zeros(2,3, celltype=SymmetricTensor2D_T{Float64})    == CellArrays.fill!(CPUCellArray{SymmetricTensor2D_T{Float64}}(undef,2,3), SymmetricTensor2D_T{Float64}(zeros(3)))
                    @test @zeros(2,3, celltype=SymmetricTensor2D_Float32)       == CellArrays.fill!(CPUCellArray{SymmetricTensor2D_Float32}(undef,2,3), SymmetricTensor2D_Float32(zeros(3)))
                    @test @ones(2,3, celltype=SymmetricTensor2D)                == CellArrays.fill!(CPUCellArray{SymmetricTensor2D}(undef,2,3), SymmetricTensor2D(ones(3)))
                    @test typeof(@rand(2,3, celltype=SymmetricTensor2D))        == typeof(CPUCellArray{SymmetricTensor2D,1}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celltype=SymmetricTensor2D))     == typeof(CPUCellArray{SymmetricTensor2D,1}(undef,2,3))
                    @test @zeros(2,3, celltype=SymmetricTensor2D_Index)         == CellArrays.fill!(CPUCellArray{SymmetricTensor2D_Index}(undef,2,3), SymmetricTensor2D_Index(zeros(3)))
                end
            end;
            @reset_parallel_kernel()
        end;
        @testset "3. allocator macros (no default numbertype)" begin            # Note: these tests are exact copies of 1. with the tests without eltype kwarg removed though (i.e., every 2nd test removed)
            @require !@is_initialized()
            @init_parallel_kernel(package = $package)
            @require @is_initialized()
            @require @get_numbertype() == NUMBERTYPE_NONE
            @testset "datatype definitions" begin
                @CellType SymmetricTensor2D fieldnames=(xx, zz, xz) eltype=Float16
                @CellType SymmetricTensor3D fieldnames=(xx, yy, zz, yz, xz, xy) eltype=Float16
                @CellType Tensor2D fieldnames=(xxxx, yxxx, xyxx, yyxx, xxyx, yxyx, xyyx, yyyx, xxxy, yxxy, xyxy, yyxy, xxyy, yxyy, xyyy, yyyy) dims=(2,2,2,2) eltype=Float16
                @CellType SymmetricTensor2D_T fieldnames=(xx, zz, xz) parametric=true
                @CellType SymmetricTensor2D_Float32 fieldnames=(xx, zz, xz) eltype=Float32
                @CellType SymmetricTensor2D_Bool fieldnames=(xx, zz, xz) eltype=Bool
                @test SymmetricTensor2D <: FieldArray
                @test SymmetricTensor3D <: FieldArray
                @test Tensor2D <: FieldArray
                @test SymmetricTensor2D_T <: FieldArray
                @test SymmetricTensor2D_Float32 <: FieldArray
                @test SymmetricTensor2D_Bool <: FieldArray
            end;
            @testset "mapping to package (no celldims/celltype)" begin
                @static if $package == $PKG_CUDA
                    @test typeof(@zeros(2,3, eltype=Float32))    == typeof(CUDA.CuArray(zeros(Float32,2,3)))
                    @test typeof(@ones(2,3, eltype=Float32))     == typeof(CUDA.CuArray(ones(Float32,2,3)))
                    @test typeof(@rand(2,3, eltype=Float64))     == typeof(CUDA.CuArray(rand(Float64,2,3)))
                    @test typeof(@fill(9, 2,3, eltype=Float64))  == typeof(CUDA.CuArray(fill(convert(Float64, 9), 2,3)))
                    @test typeof(@zeros(2,3, eltype=DATA_INDEX)) == typeof(CUDA.CuArray(zeros(DATA_INDEX,2,3)))
                elseif $package == $PKG_AMDGPU
                    @test typeof(@zeros(2,3, eltype=Float32))    == typeof(AMDGPU.ROCArray(zeros(Float32,2,3)))
                    @test typeof(@ones(2,3, eltype=Float32))     == typeof(AMDGPU.ROCArray(ones(Float32,2,3)))
                    @test typeof(@rand(2,3, eltype=Float64))     == typeof(AMDGPU.ROCArray(rand(Float64,2,3)))
                    @test typeof(@fill(9, 2,3, eltype=Float64))  == typeof(AMDGPU.ROCArray(fill(convert(Float64, 9), 2,3)))
                    @test typeof(@zeros(2,3, eltype=DATA_INDEX)) == typeof(AMDGPU.ROCArray(zeros(DATA_INDEX,2,3)))
                elseif $package == $PKG_METAL
                    @test typeof(@zeros(2,3, eltype=Float32))    == typeof(Metal.MtlArray(zeros(Float32,2,3)))
                    @test typeof(@ones(2,3, eltype=Float32))     == typeof(Metal.MtlArray(ones(Float32,2,3)))
                    @test typeof(@rand(2,3, eltype=Float32))     == typeof(Metal.MtlArray(rand(Float32,2,3)))
                    @test typeof(@fill(9, 2,3, eltype=Float32))  == typeof(Metal.MtlArray(fill(convert(Float32, 9), 2,3)))
                    @test typeof(@zeros(2,3, eltype=DATA_INDEX)) == typeof(Metal.MtlArray(zeros(DATA_INDEX,2,3)))
                else
                    @test typeof(@zeros(2,3, eltype=Float32))    == typeof(zeros(Float32,2,3))
                    @test typeof(@ones(2,3, eltype=Float32))     == typeof(ones(Float32,2,3))
                    @test typeof(@rand(2,3, eltype=Float64))     == typeof(parentmodule($package).rand(Float64,2,3))
                    @test typeof(@fill(9, 2,3, eltype=Float64))  == typeof(fill(convert(Float64, 9), 2,3))
                    @test typeof(@zeros(2,3, eltype=DATA_INDEX)) == typeof(zeros(DATA_INDEX,2,3))
                end
                @test Array(@falses(2,3)) == Array(parentmodule($package).falses(2,3))
                @test Array(@trues(2,3))  == Array(parentmodule($package).trues(2,3))
            end;
            @testset "mapping to package (with celldims)" begin
                T_Float16 = SMatrix{(3,4)..., Float16, prod((3,4))}
                T_Float32 = SMatrix{(3,4)..., Float32, prod((3,4))}
                T_Float64 = SMatrix{(3,4)..., Float64, prod((3,4))}
                T_Bool    = SMatrix{(3,4)..., Bool,    prod((3,4))}
                @static if $package == $PKG_CUDA
                    CUDA.allowscalar(true)
                    @test @zeros(2,3, celldims=(3,4), eltype=Float32)           == CellArrays.fill!(CuCellArray{T_Float32}(undef,2,3), T_Float32(zeros((3,4))))
                    @test @ones(2,3, celldims=(3,4), eltype=Float32)            == CellArrays.fill!(CuCellArray{T_Float32}(undef,2,3), T_Float32(ones((3,4))))
                    @test typeof(@rand(2,3, celldims=(3,4), eltype=Float64))    == typeof(CuCellArray{T_Float64,0}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4), eltype=Float64)) == typeof(CuCellArray{T_Float64,0}(undef,2,3))
                    @test @falses(2,3, celldims=(3,4))                          == CellArrays.fill!(CuCellArray{T_Bool}(undef,2,3), falses((3,4)))
                    @test @trues(2,3, celldims=(3,4))                           == CellArrays.fill!(CuCellArray{T_Bool}(undef,2,3), trues((3,4)))
                    CUDA.allowscalar(false)
                elseif $package == $PKG_AMDGPU
                    AMDGPU.allowscalar(true)
                    @test @zeros(2,3, celldims=(3,4), eltype=Float32)           == CellArrays.fill!(ROCCellArray{T_Float32}(undef,2,3), T_Float32(zeros((3,4))))
                    @test @ones(2,3, celldims=(3,4), eltype=Float32)            == CellArrays.fill!(ROCCellArray{T_Float32}(undef,2,3), T_Float32(ones((3,4))))
                    @test typeof(@rand(2,3, celldims=(3,4), eltype=Float64))    == typeof(ROCCellArray{T_Float64,0}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4), eltype=Float64)) == typeof(ROCCellArray{T_Float64,0}(undef,2,3))
                    @test @falses(2,3, celldims=(3,4))                          == CellArrays.fill!(ROCCellArray{T_Bool}(undef,2,3), falses((3,4)))
                    @test @trues(2,3, celldims=(3,4))                           == CellArrays.fill!(ROCCellArray{T_Bool}(undef,2,3), trues((3,4)))
                    AMDGPU.allowscalar(false)
                elseif $package == $PKG_METAL
                    Metal.allowscalar(true)
                    @test @zeros(2,3, celldims=(3,4), eltype=Float32)           == CellArrays.fill!(MtlCellArray{T_Float32}(undef,2,3), T_Float32(zeros((3,4))))
                    @test @ones(2,3, celldims=(3,4), eltype=Float32)            == CellArrays.fill!(MtlCellArray{T_Float32}(undef,2,3), T_Float32(ones((3,4))))
                    @test typeof(@rand(2,3, celldims=(3,4), eltype=Float32))    == typeof(MtlCellArray{T_Float32,0}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4), eltype=Float32)) == typeof(MtlCellArray{T_Float32,0}(undef,2,3))
                    @test @falses(2,3, celldims=(3,4))                          == CellArrays.fill!(MtlCellArray{T_Bool}(undef,2,3), falses((3,4)))
                    @test @trues(2,3, celldims=(3,4))                           == CellArrays.fill!(MtlCellArray{T_Bool}(undef,2,3), trues((3,4)))
                    Metal.allowscalar(false)
                else
                    @test @zeros(2,3, celldims=(3,4), eltype=Float32)           == CellArrays.fill!(CPUCellArray{T_Float32}(undef,2,3), T_Float32(zeros((3,4))))
                    @test @ones(2,3, celldims=(3,4), eltype=Float32)            == CellArrays.fill!(CPUCellArray{T_Float32}(undef,2,3), T_Float32(ones((3,4))))
                    @test typeof(@rand(2,3, celldims=(3,4), eltype=Float64))    == typeof(CPUCellArray{T_Float64,1}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4), eltype=Float64)) == typeof(CPUCellArray{T_Float64,1}(undef,2,3))
                    @test @falses(2,3, celldims=(3,4))                          == CellArrays.fill!(CPUCellArray{T_Bool}(undef,2,3), falses((3,4)))
                    @test @trues(2,3, celldims=(3,4))                           == CellArrays.fill!(CPUCellArray{T_Bool}(undef,2,3), trues((3,4)))
                end
            end;
            @testset "mapping to package (with celltype)" begin
                @static if $package == $PKG_CUDA
                    CUDA.allowscalar(true)
                    @test @zeros(2,3, celltype=SymmetricTensor2D)               == CellArrays.fill!(CuCellArray{SymmetricTensor2D}(undef,2,3), SymmetricTensor2D(zeros(3)))
                    @test @zeros(2,3, celltype=SymmetricTensor3D)               == CellArrays.fill!(CuCellArray{SymmetricTensor3D}(undef,2,3), SymmetricTensor3D(zeros(6)))
                    @test @zeros(2,3, celltype=Tensor2D)                        == CellArrays.fill!(CuCellArray{Tensor2D}(undef,2,3), Tensor2D(zeros((2,2,2,2))))
                    @test @zeros(2,3, celltype=SymmetricTensor2D_T{Float64})    == CellArrays.fill!(CuCellArray{SymmetricTensor2D_T{Float64}}(undef,2,3), SymmetricTensor2D_T{Float64}(zeros(3)))
                    @test @zeros(2,3, celltype=SymmetricTensor2D_Float32)       == CellArrays.fill!(CuCellArray{SymmetricTensor2D_Float32}(undef,2,3), SymmetricTensor2D_Float32(zeros(3)))
                    @test @ones(2,3, celltype=SymmetricTensor2D)                == CellArrays.fill!(CuCellArray{SymmetricTensor2D}(undef,2,3), SymmetricTensor2D(ones(3)))
                    @test typeof(@rand(2,3, celltype=SymmetricTensor2D))        == typeof(CuCellArray{SymmetricTensor2D,0}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celltype=SymmetricTensor2D))     == typeof(CuCellArray{SymmetricTensor2D,0}(undef,2,3))
                    CUDA.allowscalar(false)
                elseif $package == $PKG_AMDGPU
                    AMDGPU.allowscalar(true)
                    @test @zeros(2,3, celltype=SymmetricTensor2D)               == CellArrays.fill!(ROCCellArray{SymmetricTensor2D}(undef,2,3), SymmetricTensor2D(zeros(3)))
                    @test @zeros(2,3, celltype=SymmetricTensor3D)               == CellArrays.fill!(ROCCellArray{SymmetricTensor3D}(undef,2,3), SymmetricTensor3D(zeros(6)))
                    @test @zeros(2,3, celltype=Tensor2D)                        == CellArrays.fill!(ROCCellArray{Tensor2D}(undef,2,3), Tensor2D(zeros((2,2,2,2))))
                    @test @zeros(2,3, celltype=SymmetricTensor2D_T{Float64})    == CellArrays.fill!(ROCCellArray{SymmetricTensor2D_T{Float64}}(undef,2,3), SymmetricTensor2D_T{Float64}(zeros(3)))
                    @test @zeros(2,3, celltype=SymmetricTensor2D_Float32)       == CellArrays.fill!(ROCCellArray{SymmetricTensor2D_Float32}(undef,2,3), SymmetricTensor2D_Float32(zeros(3)))
                    @test @ones(2,3, celltype=SymmetricTensor2D)                == CellArrays.fill!(ROCCellArray{SymmetricTensor2D}(undef,2,3), SymmetricTensor2D(ones(3)))
                    @test typeof(@rand(2,3, celltype=SymmetricTensor2D))        == typeof(ROCCellArray{SymmetricTensor2D,0}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celltype=SymmetricTensor2D))     == typeof(ROCCellArray{SymmetricTensor2D,0}(undef,2,3))
                    AMDGPU.allowscalar(false)
                elseif $package == $PKG_METAL
                    Metal.allowscalar(true)
                    @test @zeros(2,3, celltype=SymmetricTensor2D)               == CellArrays.fill!(MtlCellArray{SymmetricTensor2D}(undef,2,3), SymmetricTensor2D(zeros(3)))
                    @test @zeros(2,3, celltype=SymmetricTensor3D)               == CellArrays.fill!(MtlCellArray{SymmetricTensor3D}(undef,2,3), SymmetricTensor3D(zeros(6)))
                    @test @zeros(2,3, celltype=Tensor2D)                        == CellArrays.fill!(MtlCellArray{Tensor2D}(undef,2,3), Tensor2D(zeros((2,2,2,2))))
                    @test @zeros(2,3, celltype=SymmetricTensor2D_T{Float32})    == CellArrays.fill!(MtlCellArray{SymmetricTensor2D_T{Float32}}(undef,2,3), SymmetricTensor2D_T{Float32}(zeros(3)))
                    @test @zeros(2,3, celltype=SymmetricTensor2D_Float32)       == CellArrays.fill!(MtlCellArray{SymmetricTensor2D_Float32}(undef,2,3), SymmetricTensor2D_Float32(zeros(3)))
                    @test @ones(2,3, celltype=SymmetricTensor2D)                == CellArrays.fill!(MtlCellArray{SymmetricTensor2D}(undef,2,3), SymmetricTensor2D(ones(3)))
                    @test typeof(@rand(2,3, celltype=SymmetricTensor2D))        == typeof(MtlCellArray{SymmetricTensor2D,0}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celltype=SymmetricTensor2D))     == typeof(MtlCellArray{SymmetricTensor2D,0}(undef,2,3))
                    Metal.allowscalar(false)
                else
                    @test @zeros(2,3, celltype=SymmetricTensor2D)               == CellArrays.fill!(CPUCellArray{SymmetricTensor2D}(undef,2,3), SymmetricTensor2D(zeros(3)))
                    @test @zeros(2,3, celltype=SymmetricTensor3D)               == CellArrays.fill!(CPUCellArray{SymmetricTensor3D}(undef,2,3), SymmetricTensor3D(zeros(6)))
                    @test @zeros(2,3, celltype=Tensor2D)                        == CellArrays.fill!(CPUCellArray{Tensor2D}(undef,2,3), Tensor2D(zeros((2,2,2,2))))
                    @test @zeros(2,3, celltype=SymmetricTensor2D_T{Float64})    == CellArrays.fill!(CPUCellArray{SymmetricTensor2D_T{Float64}}(undef,2,3), SymmetricTensor2D_T{Float64}(zeros(3)))
                    @test @zeros(2,3, celltype=SymmetricTensor2D_Float32)       == CellArrays.fill!(CPUCellArray{SymmetricTensor2D_Float32}(undef,2,3), SymmetricTensor2D_Float32(zeros(3)))
                    @test @ones(2,3, celltype=SymmetricTensor2D)                == CellArrays.fill!(CPUCellArray{SymmetricTensor2D}(undef,2,3), SymmetricTensor2D(ones(3)))
                    @test typeof(@rand(2,3, celltype=SymmetricTensor2D))        == typeof(CPUCellArray{SymmetricTensor2D,1}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celltype=SymmetricTensor2D))     == typeof(CPUCellArray{SymmetricTensor2D,1}(undef,2,3))
                end
            end;
            @reset_parallel_kernel()
        end;
        @testset "4. blocklength" begin
            @require !@is_initialized()
            @init_parallel_kernel($package, Float16)
            @require @is_initialized()
            T_Float16 = SMatrix{(3,4)..., Float16, prod((3,4))}
            T_Bool    = SMatrix{(3,4)..., Bool,    prod((3,4))}
            @testset "default" begin    
                @static if $package == $PKG_CUDA
                    CUDA.allowscalar(true)
                    @test typeof(  @zeros(2,3, celldims=(3,4)))                 == typeof(CuCellArray{T_Float16,0}(undef,2,3))
                    @test typeof(   @ones(2,3, celldims=(3,4)))                 == typeof(CuCellArray{T_Float16,0}(undef,2,3))
                    @test typeof(   @rand(2,3, celldims=(3,4)))                 == typeof(CuCellArray{T_Float16,0}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4)))                 == typeof(CuCellArray{T_Float16,0}(undef,2,3))
                    @test typeof( @falses(2,3, celldims=(3,4)))                 == typeof(CuCellArray{T_Bool,   0}(undef,2,3))
                    @test typeof(  @trues(2,3, celldims=(3,4)))                 == typeof(CuCellArray{T_Bool,   0}(undef,2,3))
                    CUDA.allowscalar(false)
                elseif $package == $PKG_AMDGPU
                    AMDGPU.allowscalar(true)
                    @test typeof(  @zeros(2,3, celldims=(3,4)))                 == typeof(ROCCellArray{T_Float16,0}(undef,2,3))
                    @test typeof(   @ones(2,3, celldims=(3,4)))                 == typeof(ROCCellArray{T_Float16,0}(undef,2,3))
                    @test typeof(   @rand(2,3, celldims=(3,4)))                 == typeof(ROCCellArray{T_Float16,0}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4)))                 == typeof(ROCCellArray{T_Float16,0}(undef,2,3))
                    @test typeof( @falses(2,3, celldims=(3,4)))                 == typeof(ROCCellArray{T_Bool,   0}(undef,2,3))
                    @test typeof(  @trues(2,3, celldims=(3,4)))                 == typeof(ROCCellArray{T_Bool,   0}(undef,2,3))
                    AMDGPU.allowscalar(false)
                elseif $package == $PKG_METAL
                    Metal.allowscalar(true)
                    @test typeof(  @zeros(2,3, celldims=(3,4)))                 == typeof(MtlCellArray{T_Float16,0}(undef,2,3))
                    @test typeof(   @ones(2,3, celldims=(3,4)))                 == typeof(MtlCellArray{T_Float16,0}(undef,2,3))
                    @test typeof(   @rand(2,3, celldims=(3,4)))                 == typeof(MtlCellArray{T_Float16,0}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4)))                 == typeof(MtlCellArray{T_Float16,0}(undef,2,3))
                    @test typeof( @falses(2,3, celldims=(3,4)))                 == typeof(MtlCellArray{T_Bool,   0}(undef,2,3))
                    @test typeof(  @trues(2,3, celldims=(3,4)))                 == typeof(MtlCellArray{T_Bool,   0}(undef,2,3))
                    Metal.allowscalar(false)
                else
                    @test typeof(  @zeros(2,3, celldims=(3,4)))                 == typeof(CPUCellArray{T_Float16,1}(undef,2,3))
                    @test typeof(   @ones(2,3, celldims=(3,4)))                 == typeof(CPUCellArray{T_Float16,1}(undef,2,3))
                    @test typeof(   @rand(2,3, celldims=(3,4)))                 == typeof(CPUCellArray{T_Float16,1}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4)))                 == typeof(CPUCellArray{T_Float16,1}(undef,2,3))
                    @test typeof( @falses(2,3, celldims=(3,4)))                 == typeof(CPUCellArray{T_Bool,   1}(undef,2,3))
                    @test typeof(  @trues(2,3, celldims=(3,4)))                 == typeof(CPUCellArray{T_Bool,   1}(undef,2,3))
                end
            end;
            @testset "custom" begin    
                @static if $package == $PKG_CUDA
                    CUDA.allowscalar(true)
                    @test typeof(  @zeros(2,3, celldims=(3,4), blocklength=1))  == typeof(CuCellArray{T_Float16,1}(undef,2,3))
                    @test typeof(   @ones(2,3, celldims=(3,4), blocklength=1))  == typeof(CuCellArray{T_Float16,1}(undef,2,3))
                    @test typeof(   @rand(2,3, celldims=(3,4), blocklength=1))  == typeof(CuCellArray{T_Float16,1}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4), blocklength=1))  == typeof(CuCellArray{T_Float16,1}(undef,2,3))
                    @test typeof( @falses(2,3, celldims=(3,4), blocklength=1))  == typeof(CuCellArray{T_Bool,   1}(undef,2,3))
                    @test typeof(  @trues(2,3, celldims=(3,4), blocklength=1))  == typeof(CuCellArray{T_Bool,   1}(undef,2,3))
                    @test typeof(  @zeros(2,3, celldims=(3,4), blocklength=3))  == typeof(CuCellArray{T_Float16,3}(undef,2,3))
                    @test typeof(   @ones(2,3, celldims=(3,4), blocklength=3))  == typeof(CuCellArray{T_Float16,3}(undef,2,3))
                    @test typeof(   @rand(2,3, celldims=(3,4), blocklength=3))  == typeof(CuCellArray{T_Float16,3}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4), blocklength=3))  == typeof(CuCellArray{T_Float16,3}(undef,2,3))
                    @test typeof( @falses(2,3, celldims=(3,4), blocklength=3))  == typeof(CuCellArray{T_Bool,   3}(undef,2,3))
                    @test typeof(  @trues(2,3, celldims=(3,4), blocklength=3))  == typeof(CuCellArray{T_Bool,   3}(undef,2,3))
                    CUDA.allowscalar(false)
                elseif $package == $PKG_AMDGPU
                    AMDGPU.allowscalar(true)
                    @test typeof(  @zeros(2,3, celldims=(3,4), blocklength=1))  == typeof(ROCCellArray{T_Float16,1}(undef,2,3))
                    @test typeof(   @ones(2,3, celldims=(3,4), blocklength=1))  == typeof(ROCCellArray{T_Float16,1}(undef,2,3))
                    @test typeof(   @rand(2,3, celldims=(3,4), blocklength=1))  == typeof(ROCCellArray{T_Float16,1}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4), blocklength=1))  == typeof(ROCCellArray{T_Float16,1}(undef,2,3))
                    @test typeof( @falses(2,3, celldims=(3,4), blocklength=1))  == typeof(ROCCellArray{T_Bool,   1}(undef,2,3))
                    @test typeof(  @trues(2,3, celldims=(3,4), blocklength=1))  == typeof(ROCCellArray{T_Bool,   1}(undef,2,3))
                    @test typeof(  @zeros(2,3, celldims=(3,4), blocklength=3))  == typeof(ROCCellArray{T_Float16,3}(undef,2,3))
                    @test typeof(   @ones(2,3, celldims=(3,4), blocklength=3))  == typeof(ROCCellArray{T_Float16,3}(undef,2,3))
                    @test typeof(   @rand(2,3, celldims=(3,4), blocklength=3))  == typeof(ROCCellArray{T_Float16,3}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4), blocklength=3))  == typeof(ROCCellArray{T_Float16,3}(undef,2,3))
                    @test typeof( @falses(2,3, celldims=(3,4), blocklength=3))  == typeof(ROCCellArray{T_Bool,   3}(undef,2,3))
                    @test typeof(  @trues(2,3, celldims=(3,4), blocklength=3))  == typeof(ROCCellArray{T_Bool,   3}(undef,2,3))
                    AMDGPU.allowscalar(false)
                elseif $package == $PKG_METAL
                    Metal.allowscalar(true)
                    @test typeof(  @zeros(2,3, celldims=(3,4), blocklength=1))  == typeof(MtlCellArray{T_Float16,1}(undef,2,3))
                    @test typeof(   @ones(2,3, celldims=(3,4), blocklength=1))  == typeof(MtlCellArray{T_Float16,1}(undef,2,3))
                    @test typeof(   @rand(2,3, celldims=(3,4), blocklength=1))  == typeof(MtlCellArray{T_Float16,1}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4), blocklength=1))  == typeof(MtlCellArray{T_Float16,1}(undef,2,3))
                    @test typeof( @falses(2,3, celldims=(3,4), blocklength=1))  == typeof(MtlCellArray{T_Bool,   1}(undef,2,3))
                    @test typeof(  @trues(2,3, celldims=(3,4), blocklength=1))  == typeof(MtlCellArray{T_Bool,   1}(undef,2,3))
                    @test typeof(  @zeros(2,3, celldims=(3,4), blocklength=3))  == typeof(MtlCellArray{T_Float16,3}(undef,2,3))
                    @test typeof(   @ones(2,3, celldims=(3,4), blocklength=3))  == typeof(MtlCellArray{T_Float16,3}(undef,2,3))
                    @test typeof(   @rand(2,3, celldims=(3,4), blocklength=3))  == typeof(MtlCellArray{T_Float16,3}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4), blocklength=3))  == typeof(MtlCellArray{T_Float16,3}(undef,2,3))
                    @test typeof( @falses(2,3, celldims=(3,4), blocklength=3))  == typeof(MtlCellArray{T_Bool,   3}(undef,2,3))
                    @test typeof(  @trues(2,3, celldims=(3,4), blocklength=3))  == typeof(MtlCellArray{T_Bool,   3}(undef,2,3))
                    Metal.allowscalar(false)
                else
                    @test typeof(  @zeros(2,3, celldims=(3,4), blocklength=0))  == typeof(CPUCellArray{T_Float16,0}(undef,2,3))
                    @test typeof(   @ones(2,3, celldims=(3,4), blocklength=0))  == typeof(CPUCellArray{T_Float16,0}(undef,2,3))
                    @test typeof(   @rand(2,3, celldims=(3,4), blocklength=0))  == typeof(CPUCellArray{T_Float16,0}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4), blocklength=0))  == typeof(CPUCellArray{T_Float16,0}(undef,2,3))
                    @test typeof( @falses(2,3, celldims=(3,4), blocklength=0))  == typeof(CPUCellArray{T_Bool,   0}(undef,2,3))
                    @test typeof(  @trues(2,3, celldims=(3,4), blocklength=0))  == typeof(CPUCellArray{T_Bool,   0}(undef,2,3))
                    @test typeof(  @zeros(2,3, celldims=(3,4), blocklength=3))  == typeof(CPUCellArray{T_Float16,3}(undef,2,3))
                    @test typeof(   @ones(2,3, celldims=(3,4), blocklength=3))  == typeof(CPUCellArray{T_Float16,3}(undef,2,3))
                    @test typeof(   @rand(2,3, celldims=(3,4), blocklength=3))  == typeof(CPUCellArray{T_Float16,3}(undef,2,3))
                    @test typeof(@fill(9, 2,3, celldims=(3,4), blocklength=3))  == typeof(CPUCellArray{T_Float16,3}(undef,2,3))
                    @test typeof( @falses(2,3, celldims=(3,4), blocklength=3))  == typeof(CPUCellArray{T_Bool,   3}(undef,2,3))
                    @test typeof(  @trues(2,3, celldims=(3,4), blocklength=3))  == typeof(CPUCellArray{T_Bool,   3}(undef,2,3))
                end
            end;
            @reset_parallel_kernel()
        end;
        @testset "5. Enums" begin
            @require !@is_initialized()
            @init_parallel_kernel($package, Float16)
            @require @is_initialized()
            @enum Phase air fluid solid
            T_Phase = SMatrix{(3,4)..., Phase, prod((3,4))}
            @static if $package == $PKG_CUDA
                CUDA.allowscalar(true)
                @test typeof(@rand(2,3, eltype=Phase))                                          == typeof(CUDA.CuArray(rand(Phase, 2,3)))
                @test typeof(@rand(2,3, celldims=(3,4), eltype=Phase))                          == typeof(CuCellArray{T_Phase,0}(undef,2,3))
                @test typeof(@fill(solid, 2,3, eltype=Phase))                                   == typeof(CUDA.CuArray(rand(Phase, 2,3)))
                @test typeof(@fill(solid, 2,3, celldims=(3,4), eltype=Phase))                   == typeof(CuCellArray{T_Phase,0}(undef,2,3))
                @test typeof(@fill(@rand(3,4,eltype=Phase), 2,3, celldims=(3,4), eltype=Phase)) == typeof(CuCellArray{T_Phase,0}(undef,2,3))
                CUDA.allowscalar(false)
            elseif $package == $PKG_AMDGPU
                AMDGPU.allowscalar(true)
                @test typeof(@rand(2,3, eltype=Phase))                                          == typeof(AMDGPU.ROCArray(rand(Phase, 2,3)))
                @test typeof(@rand(2,3, celldims=(3,4), eltype=Phase))                          == typeof(ROCCellArray{T_Phase,0}(undef,2,3))
                @test typeof(@fill(solid, 2,3, eltype=Phase))                                   == typeof(AMDGPU.ROCArray(rand(Phase, 2,3)))
                @test typeof(@fill(solid, 2,3, celldims=(3,4), eltype=Phase))                   == typeof(ROCCellArray{T_Phase,0}(undef,2,3))
                @test typeof(@fill(@rand(3,4,eltype=Phase), 2,3, celldims=(3,4), eltype=Phase)) == typeof(ROCCellArray{T_Phase,0}(undef,2,3))
                AMDGPU.allowscalar(false)
            elseif $package == $PKG_METAL
                Metal.allowscalar(true)
                @test typeof(@rand(2,3, eltype=Phase))                                          == typeof(Metal.MtlArray(rand(Phase, 2,3)))
                # @test typeof(@rand(2,3, celldims=(3,4), eltype=Phase))                          == typeof(MtlCellArray{T_Phase,0}(undef,2,3)) # TODO fails because of bug in Metal.jl RNG implementation
                @test typeof(@fill(solid, 2,3, eltype=Phase))                                   == typeof(Metal.MtlArray(rand(Phase, 2,3)))
                @test typeof(@fill(solid, 2,3, celldims=(3,4), eltype=Phase))                   == typeof(MtlCellArray{T_Phase,0}(undef,2,3))
                @test typeof(@fill(@rand(3,4,eltype=Phase), 2,3, celldims=(3,4), eltype=Phase)) == typeof(MtlCellArray{T_Phase,0}(undef,2,3))
                Metal.allowscalar(false)
            else
                @test typeof(@rand(2,3, eltype=Phase))                                          == typeof(rand(Phase, 2,3))
                @test typeof(@rand(2,3, celldims=(3,4), eltype=Phase))                          == typeof(CPUCellArray{T_Phase,1}(undef,2,3))
                @test typeof(@fill(solid, 2,3, eltype=Phase))                                   == typeof(fill(solid, 2,3))
                @test typeof(@fill(solid, 2,3, celldims=(3,4), eltype=Phase))                   == typeof(CPUCellArray{T_Phase,1}(undef,2,3))
                @test typeof(@fill(@rand(3,4,eltype=Phase), 2,3, celldims=(3,4), eltype=Phase)) == typeof(CPUCellArray{T_Phase,1}(undef,2,3))
            end
            @reset_parallel_kernel()
        end;
        $(interpolate(:__padding__, (false, true), :(
            @testset "6. Fields (padding=$__padding__)" begin
                @require !@is_initialized()
                @init_parallel_kernel($package, Float16, padding=__padding__)
                @require @is_initialized()
                (nx, ny, nz) = (3, 4, 5)
                @testset "mapping to array allocators" begin
                    @testset "Field" begin
                        @test occursin("@zeros", @prettystring(1, @Field((nx, ny, nz))))
                        @test occursin("@zeros", @prettystring(1, @Field((nx, ny, nz), @zeros)))
                        @test occursin("@ones",  @prettystring(1, @Field((nx, ny, nz), @ones)))
                        @test occursin("@rand",  @prettystring(1, @Field((nx, ny, nz), @rand)))
                        @test occursin("@falses",@prettystring(1, @Field((nx, ny, nz), @falses)))
                        @test occursin("@trues", @prettystring(1, @Field((nx, ny, nz), @trues)))
                    end;
                    @testset "[B]{X|Y|Z}Field" begin
                        @test occursin("@zeros", @prettystring(1, @XField((nx, ny, nz))))
                        @test occursin("@zeros", @prettystring(1, @YField((nx, ny, nz), @zeros)))
                        @test occursin("@ones",  @prettystring(1, @ZField((nx, ny, nz), @ones)))
                        @test occursin("@rand",  @prettystring(1, @BXField((nx, ny, nz), @rand)))
                        @test occursin("@falses",@prettystring(1, @BYField((nx, ny, nz), @falses)))
                        @test occursin("@trues", @prettystring(1, @BZField((nx, ny, nz), @trues)))
                    end;
                    @testset "{XX|YY|ZZ|XY|XZ|YZ}Field" begin
                        @test occursin("@zeros", @prettystring(1, @XXField((nx, ny, nz), eltype=Float32)))
                        @test occursin("@zeros", @prettystring(1, @YYField((nx, ny, nz), @zeros, eltype=Float32)))
                        @test occursin("@ones",  @prettystring(1, @ZZField((nx, ny, nz), @ones, eltype=Float32)))
                        @test occursin("@rand",  @prettystring(1, @XYField((nx, ny, nz), @rand, eltype=Float32)))
                        @test occursin("@falses",@prettystring(1, @XZField((nx, ny, nz), @falses, eltype=Float32)))
                        @test occursin("@trues", @prettystring(1, @YZField((nx, ny, nz), @trues, eltype=Float32)))
                    end;
                end;
                @testset "field size (3D)" begin
                    @test size(  @Field((nx, ny, nz))) == (nx,   ny,   nz  )
                    @test size( @XField((nx, ny, nz))) == (nx-1, ny-2, nz-2)
                    @test size( @YField((nx, ny, nz))) == (nx-2, ny-1, nz-2)
                    @test size( @ZField((nx, ny, nz))) == (nx-2, ny-2, nz-1)
                    @test size(@BXField((nx, ny, nz))) == (nx+1, ny,   nz  )
                    @test size(@BYField((nx, ny, nz))) == (nx,   ny+1, nz  )
                    @test size(@BZField((nx, ny, nz))) == (nx,   ny,   nz+1)
                    @test size(@XXField((nx, ny, nz))) == (nx,   ny-2, nz-2)
                    @test size(@YYField((nx, ny, nz))) == (nx-2, ny,   nz-2)
                    @test size(@ZZField((nx, ny, nz))) == (nx-2, ny-2, nz  )
                    @test size(@XYField((nx, ny, nz))) == (nx-1, ny-1, nz-2)
                    @test size(@XZField((nx, ny, nz))) == (nx-1, ny-2, nz-1)
                    @test size(@YZField((nx, ny, nz))) == (nx-2, ny-1, nz-1)
                    @test size.(Tuple( @VectorField((nx, ny, nz)))) == (size( @XField((nx, ny, nz))), size( @YField((nx, ny, nz))), size( @ZField((nx, ny, nz))))
                    @test size.(Tuple(@BVectorField((nx, ny, nz)))) == (size(@BXField((nx, ny, nz))), size(@BYField((nx, ny, nz))), size(@BZField((nx, ny, nz))))
                    @test size.(Tuple( @TensorField((nx, ny, nz)))) == (size(@XXField((nx, ny, nz))), size(@YYField((nx, ny, nz))), size(@ZZField((nx, ny, nz))), 
                                                                        size(@XYField((nx, ny, nz))), size(@XZField((nx, ny, nz))), size(@YZField((nx, ny, nz))))
                end;
                @testset "field size (2D)" begin
                    @test size(  @Field((nx, ny))) == (nx,   ny, )
                    @test size( @XField((nx, ny))) == (nx-1, ny-2)
                    @test size( @YField((nx, ny))) == (nx-2, ny-1)
                    @test size( @ZField((nx, ny))) == (nx-2, ny-2)
                    @test size(@BXField((nx, ny))) == (nx+1, ny, )
                    @test size(@BYField((nx, ny))) == (nx,   ny+1)
                    @test size(@BZField((nx, ny))) == (nx,   ny, )
                    @test size(@XXField((nx, ny))) == (nx,   ny-2)
                    @test size(@YYField((nx, ny))) == (nx-2, ny, )
                    @test size(@ZZField((nx, ny))) == (nx-2, ny-2)
                    @test size(@XYField((nx, ny))) == (nx-1, ny-1)
                    @test size(@XZField((nx, ny))) == (nx-1, ny-2)
                    @test size(@YZField((nx, ny))) == (nx-2, ny-1)
                    @test size.(Tuple( @VectorField((nx, ny)))) == (size( @XField((nx, ny))), size( @YField((nx, ny))))
                    @test size.(Tuple(@BVectorField((nx, ny)))) == (size(@BXField((nx, ny))), size(@BYField((nx, ny))))
                    @test size.(Tuple( @TensorField((nx, ny)))) == (size(@XXField((nx, ny))), size(@YYField((nx, ny))),
                                                                    size(@XYField((nx, ny))))
                end;
                @testset "field size (1D)" begin
                    @test size(  @Field((nx,))) ==  (nx,  )
                    @test size( @XField((nx,))) ==  (nx-1,)
                    @test size( @YField((nx,))) ==  (nx-2,)
                    @test size( @ZField((nx,))) ==  (nx-2,)
                    @test size(@BXField((nx,))) ==  (nx+1,)
                    @test size(@BYField((nx,))) ==  (nx,  )
                    @test size(@BZField((nx,))) ==  (nx,  )
                    @test size(@XXField((nx,))) ==  (nx,  )
                    @test size(@YYField((nx,))) ==  (nx-2,)
                    @test size(@ZZField((nx,))) ==  (nx-2,)
                    @test size(@XYField((nx,))) ==  (nx-1,)
                    @test size(@XZField((nx,))) ==  (nx-1,)
                    @test size(@YZField((nx,))) ==  (nx-2,)
                    @test size.(Tuple( @VectorField((nx,)))) == (size( @XField((nx,))),)
                    @test size.(Tuple(@BVectorField((nx,)))) == (size(@BXField((nx,))),)
                    @test size.(Tuple( @TensorField((nx,)))) == (size(@XXField((nx,))),)
                end;
                @static if __padding__
                    @testset "array size (3D)" begin
                        @test size(  @Field((nx, ny, nz)).parent) == (nx,   ny,   nz  )
                        @test size( @XField((nx, ny, nz)).parent) == (nx+1, ny,   nz  )
                        @test size( @YField((nx, ny, nz)).parent) == (nx,   ny+1, nz  )
                        @test size( @ZField((nx, ny, nz)).parent) == (nx,   ny,   nz+1)
                        @test size(@BXField((nx, ny, nz)).parent) == (nx+1, ny,   nz  )
                        @test size(@BYField((nx, ny, nz)).parent) == (nx,   ny+1, nz  )
                        @test size(@BZField((nx, ny, nz)).parent) == (nx,   ny,   nz+1)
                        @test size(@XXField((nx, ny, nz)).parent) == (nx,   ny,   nz  )
                        @test size(@YYField((nx, ny, nz)).parent) == (nx,   ny,   nz  )
                        @test size(@ZZField((nx, ny, nz)).parent) == (nx,   ny,   nz  )
                        @test size(@XYField((nx, ny, nz)).parent) == (nx+1, ny+1, nz  )
                        @test size(@XZField((nx, ny, nz)).parent) == (nx+1, ny,   nz+1)
                        @test size(@YZField((nx, ny, nz)).parent) == (nx,   ny+1, nz+1)
                    end;
                    @testset "array size (2D)" begin
                        @test size(  @Field((nx, ny)).parent) == (nx,   ny  )
                        @test size( @XField((nx, ny)).parent) == (nx+1, ny  )
                        @test size( @YField((nx, ny)).parent) == (nx,   ny+1)
                        @test size( @ZField((nx, ny)).parent) == (nx,   ny  )
                        @test size(@BXField((nx, ny)).parent) == (nx+1, ny  )
                        @test size(@BYField((nx, ny)).parent) == (nx,   ny+1)
                        @test size(@BZField((nx, ny)).parent) == (nx,   ny  )
                        @test size(@XXField((nx, ny)).parent) == (nx,   ny  )
                        @test size(@YYField((nx, ny)).parent) == (nx,   ny  )
                        @test size(@ZZField((nx, ny)).parent) == (nx,   ny  )
                        @test size(@XYField((nx, ny)).parent) == (nx+1, ny+1)
                        @test size(@XZField((nx, ny)).parent) == (nx+1, ny  )
                        @test size(@YZField((nx, ny)).parent) == (nx,   ny+1)
                    end;
                    # TODO: these tests fail for CUDA (most certainly a bug in CUDA)
                    # @testset "array size (1D)" begin
                    #     @test size(  @Field((nx,)).parent) == (nx,  )
                    #     @test size( @XField((nx,)).parent) == (nx+1,)
                    #     @test size( @YField((nx,)).parent) == (nx,  )
                    #     @test size( @ZField((nx,)).parent) == (nx,  )
                    #     @test size(@BXField((nx,)).parent) == (nx+1,)
                    #     @test size(@BYField((nx,)).parent) == (nx,  )
                    #     @test size(@BZField((nx,)).parent) == (nx,  )
                    #     @test size(@XXField((nx,)).parent) == (nx,  )
                    #     @test size(@YYField((nx,)).parent) == (nx,  )
                    #     @test size(@ZZField((nx,)).parent) == (nx,  )
                    #     @test size(@XYField((nx,)).parent) == (nx+1,)
                    #     @test size(@XZField((nx,)).parent) == (nx+1,)
                    #     @test size(@YZField((nx,)).parent) == (nx,  )
                    # end;
                    @testset "view ranges (3D)" begin
                        @test   @Field((nx, ny, nz)).indices == (1:nx,   1:ny,   1:nz  )
                        @test  @XField((nx, ny, nz)).indices == (2:nx,   2:ny-1, 2:nz-1)
                        @test  @YField((nx, ny, nz)).indices == (2:nx-1, 2:ny,   2:nz-1)
                        @test  @ZField((nx, ny, nz)).indices == (2:nx-1, 2:ny-1, 2:nz  )
                        @test @BXField((nx, ny, nz)).indices == (1:nx+1, 1:ny,   1:nz  )
                        @test @BYField((nx, ny, nz)).indices == (1:nx,   1:ny+1, 1:nz  )
                        @test @BZField((nx, ny, nz)).indices == (1:nx,   1:ny,   1:nz+1)
                        @test @XXField((nx, ny, nz)).indices == (1:nx,   2:ny-1, 2:nz-1)
                        @test @YYField((nx, ny, nz)).indices == (2:nx-1, 1:ny,   2:nz-1)
                        @test @ZZField((nx, ny, nz)).indices == (2:nx-1, 2:ny-1, 1:nz  )
                        @test @XYField((nx, ny, nz)).indices == (2:nx,   2:ny,   2:nz-1)
                        @test @XZField((nx, ny, nz)).indices == (2:nx,   2:ny-1, 2:nz  )
                        @test @YZField((nx, ny, nz)).indices == (2:nx-1, 2:ny,   2:nz  )
                    end;
                    @testset "view ranges (2D)" begin
                        @test   @Field((nx, ny)).indices == (1:nx,   1:ny  )
                        @test  @XField((nx, ny)).indices == (2:nx,   2:ny-1)
                        @test  @YField((nx, ny)).indices == (2:nx-1, 2:ny  )
                        @test  @ZField((nx, ny)).indices == (2:nx-1, 2:ny-1)
                        @test @BXField((nx, ny)).indices == (1:nx+1, 1:ny  )
                        @test @BYField((nx, ny)).indices == (1:nx,   1:ny+1)
                        @test @BZField((nx, ny)).indices == (1:nx,   1:ny  )
                        @test @XXField((nx, ny)).indices == (1:nx,   2:ny-1)
                        @test @YYField((nx, ny)).indices == (2:nx-1, 1:ny  )
                        @test @ZZField((nx, ny)).indices == (2:nx-1, 2:ny-1)
                        @test @XYField((nx, ny)).indices == (2:nx,   2:ny  )
                        @test @XZField((nx, ny)).indices == (2:nx,   2:ny-1)
                        @test @YZField((nx, ny)).indices == (2:nx-1, 2:ny  )
                    end;
                    # TODO: these tests fail for CUDA (most certainly a bug in CUDA)
                    # @testset "view ranges (1D)" begin
                    #     @test   @Field((nx,)).indices == (1:nx,  )
                    #     @test  @XField((nx,)).indices == (2:nx,  )
                    #     @test  @YField((nx,)).indices == (2:nx-1,)
                    #     @test  @ZField((nx,)).indices == (2:nx-1,)
                    #     @test @BXField((nx,)).indices == (1:nx+1,)
                    #     @test @BYField((nx,)).indices == (1:nx,  )
                    #     @test @BZField((nx,)).indices == (1:nx,  )
                    #     @test @XXField((nx,)).indices == (1:nx,  )
                    #     @test @YYField((nx,)).indices == (2:nx-1,)
                    #     @test @ZZField((nx,)).indices == (2:nx-1,)
                    #     @test @XYField((nx,)).indices == (2:nx,  )
                    #     @test @XZField((nx,)).indices == (2:nx,  )
                    #     @test @YZField((nx,)).indices == (2:nx-1,)
                    # end;
                end;
                @testset "eltype" begin
                    @test eltype(@Field((nx, ny, nz))) == Float16
                    @test eltype(@Field((nx, ny, nz), eltype=Float32)) == Float32
                    @test eltype.(Tuple(@VectorField((nx, ny, nz)))) == (Float16, Float16, Float16)
                    @test eltype.(Tuple(@VectorField((nx, ny, nz), eltype=Float32))) == (Float32, Float32, Float32)
                    @test eltype.(Tuple(@BVectorField((nx, ny, nz)))) == (Float16, Float16, Float16)
                    @test eltype.(Tuple(@BVectorField((nx, ny, nz), eltype=Float32))) == (Float32, Float32, Float32)
                    @test eltype.(Tuple(@TensorField((nx, ny, nz)))) == (Float16, Float16, Float16, Float16, Float16, Float16)
                    @test eltype.(Tuple(@TensorField((nx, ny, nz), eltype=Float32))) == (Float32, Float32, Float32, Float32, Float32, Float32)
                end;
                @testset "@allocate" begin
                    @testset "single field" begin
                        @test occursin("F = @Field((nx, ny, nz), @zeros(), eltype = Float16)", @prettystring(1, @allocate(gridsize = (nx,ny,nz), fields = (Field=>F))))
                        @test occursin("F = @Field(nxyz, @zeros(), eltype = Float16)",  @prettystring(1, @allocate(gridsize = nxyz, fields = Field=>F)))
                        @test occursin("F = @Field(nxyz, @ones(), eltype = Float16)",   @prettystring(1, @allocate(gridsize = nxyz, fields = Field=>F, allocator=@ones)))
                        @test occursin("F = @Field(nxyz, @rand(), eltype = Float16)",   @prettystring(1, @allocate(gridsize = nxyz, fields = Field=>F, allocator=@rand)))
                        @test occursin("F = @Field(nxyz, @falses(), eltype = Float16)", @prettystring(1, @allocate(gridsize = nxyz, fields = Field=>F, allocator=@falses)))
                        @test occursin("F = @Field(nxyz, @trues(), eltype = Float16)",  @prettystring(1, @allocate(gridsize = nxyz, fields = Field=>F, allocator=@trues)))
                        @test occursin("F = @Field(nxyz, @zeros(), eltype = Float32)",  @prettystring(1, @allocate(gridsize = nxyz, fields = Field=>F, eltype=Float32)))
                        @test occursin("F = @Field(nxyz, @rand(), eltype = Float32)",   @prettystring(1, @allocate(gridsize = nxyz, fields = Field=>F, eltype=Float32, allocator=@rand)))
                    end;
                    @testset "multiple fields - one per type (default allocator and eltype)" begin
                        call = @prettystring(1, @allocate(gridsize = nxyz,
                                                        fields   = (Field        => F,
                                                                    XField       => X,
                                                                    YField       => Y,
                                                                    ZField       => Z,
                                                                    BXField      => BX,
                                                                    BYField      => BY,
                                                                    BZField      => BZ,
                                                                    XXField      => XX,
                                                                    YYField      => YY,
                                                                    ZZField      => ZZ,
                                                                    XYField      => XY,
                                                                    XZField      => XZ,
                                                                    YZField      => YZ,
                                                                    VectorField  => V,
                                                                    BVectorField => BV,
                                                                    TensorField  => T) ))
                        @test occursin("F = @Field(nxyz, @zeros(), eltype = Float16)", call)
                        @test occursin("X = @XField(nxyz, @zeros(), eltype = Float16)", call)
                        @test occursin("Y = @YField(nxyz, @zeros(), eltype = Float16)", call)
                        @test occursin("Z = @ZField(nxyz, @zeros(), eltype = Float16)", call)
                        @test occursin("BX = @BXField(nxyz, @zeros(), eltype = Float16)", call)
                        @test occursin("BY = @BYField(nxyz, @zeros(), eltype = Float16)", call)
                        @test occursin("BZ = @BZField(nxyz, @zeros(), eltype = Float16)", call)
                        @test occursin("XX = @XXField(nxyz, @zeros(), eltype = Float16)", call)
                        @test occursin("YY = @YYField(nxyz, @zeros(), eltype = Float16)", call)
                        @test occursin("ZZ = @ZZField(nxyz, @zeros(), eltype = Float16)", call)
                        @test occursin("XY = @XYField(nxyz, @zeros(), eltype = Float16)", call)
                        @test occursin("XZ = @XZField(nxyz, @zeros(), eltype = Float16)", call)
                        @test occursin("YZ = @YZField(nxyz, @zeros(), eltype = Float16)", call)
                        @test occursin("V = @VectorField(nxyz, @zeros(), eltype = Float16)", call)
                        @test occursin("BV = @BVectorField(nxyz, @zeros(), eltype = Float16)", call)
                        @test occursin("T = @TensorField(nxyz, @zeros(), eltype = Float16)", call)
                    end;
                    @testset "multiple fields - multiple per type (custom allocator and eltype)" begin
                        call = @prettystring(1, @allocate(gridsize = nxyz,
                                                        fields   = (Field        => (F1, F2),
                                                                    XField       => X,
                                                                    VectorField  => (V1, V2, V3),
                                                                    TensorField  => T),
                                                        allocator = @rand,
                                                        eltype    = Float32) )
                        @test occursin("F1 = @Field(nxyz, @rand(), eltype = Float32)", call)
                        @test occursin("F2 = @Field(nxyz, @rand(), eltype = Float32)", call)
                        @test occursin("X = @XField(nxyz, @rand(), eltype = Float32)", call)
                        @test occursin("V1 = @VectorField(nxyz, @rand(), eltype = Float32)", call)
                        @test occursin("V2 = @VectorField(nxyz, @rand(), eltype = Float32)", call)
                        @test occursin("V3 = @VectorField(nxyz, @rand(), eltype = Float32)", call)
                        @test occursin("T = @TensorField(nxyz, @rand(), eltype = Float32)", call)
                    end;
                end;
                @reset_parallel_kernel()
            end;
        )))
        @testset "7. Exceptions" begin
            @require !@is_initialized()
            @init_parallel_kernel(package = $package)
            @require @is_initialized
            @testset "arguments @CellType" begin
                @test_throws ArgumentError checkargs_CellType();                                                                                       # Error: isempty(args)
                @test_throws ArgumentError checkargs_CellType(:SymmetricTensor2D, :(xx, yy, zz));                                                      # Error: length(posargs) != 1
                @test_throws ArgumentError checkargs_CellType(:SymmetricTensor2D);                                                                     # Error: length(kwargs_expr) < 1
                @test_throws ArgumentError checkargs_CellType(:SymmetricTensor2D, :(eltype=Float32), :(fieldnames=(xx, zz, xz)), :(dims=(2,3)), :(parametric=true), :(fifthkwarg="something"));  # Error: length(kwargs_expr) > 4
                @test_throws ArgumentError _CellType(@__MODULE__, :SymmetricTensor2D, eltype=Float32, dims=:((2,3)))                                # Error: isnothing(fieldnames)
                @test_throws ArgumentError _CellType(@__MODULE__, :SymmetricTensor2D, fieldnames=:((xx, zz, xz)), dims=:((2,3)))                    # Error: isnothing(eltype) && (!parametric && eltype == NUMBERTYPE_NONE)
                @test_throws ArgumentError _CellType(@__MODULE__, :SymmetricTensor2D, fieldnames=:((xx, zz, xz)), eltype=Float32, parametric=true)  # Error: !isnothing(fieldnames) && parametric
            end;
            @testset "arguments field macros" begin
                @test_throws ArgumentError checksargs_field_macros();                                         # Error: isempty(args)
                @test_throws ArgumentError checksargs_field_macros(:(eltype=Float32));                        # Error: isempty(posargs)
                @test_throws ArgumentError checksargs_field_macros(:nxyz, :@rand, :Float32);                  # Error: length(posargs) > 2
                @test_throws ArgumentError checksargs_field_macros(:nxyz, :@fill);                            # Error: unsupported allocator
                @test_throws ArgumentError checksargs_field_macros(:nxyz, :(eltype=Float32), :(something=x))  # Error: length(kwargs) > 1
            end;
            @testset "arguments @allocate" begin
                @test_throws ArgumentError checkargs_allocate();                                              # Error: isempty(args)
                @test_throws ArgumentError checkargs_allocate(:nxyz);                                         # Error: !isempty(posargs)
                @test_throws ArgumentError checkargs_allocate(:(gridsize=(3,4)));                             # Error: length(kwargs) < 2
                @test_throws ArgumentError checkargs_allocate(:(fields=(Field=>A)));                          # Error: length(kwargs) < 2
                @test_throws ArgumentError checkargs_allocate(:(gridsize=(3,4)), :(fields=(Field=>A)), :(allocator=:@rand), :(eltype=Float32), :(something=x)) # Error: length(kwargs) > 4
            end;
            @reset_parallel_kernel()
        end;
    end;
)) end == nothing || true;

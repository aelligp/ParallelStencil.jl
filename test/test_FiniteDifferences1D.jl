using Test
using ParallelStencil
import ParallelStencil: @reset_parallel_stencil, @is_initialized, SUPPORTED_PACKAGES, PKG_CUDA, PKG_AMDGPU, PKG_METAL, PKG_POLYESTER
import ParallelStencil: @require, interpolate
using ParallelStencil.FiniteDifferences1D
using ParallelStencil.FieldAllocators
import ParallelStencil.FieldAllocators: @IField
TEST_PACKAGES = SUPPORTED_PACKAGES
@static if PKG_CUDA in TEST_PACKAGES
    import CUDA
    if !CUDA.functional() TEST_PACKAGES = filter!(x->x≠PKG_CUDA, TEST_PACKAGES) end
end
@static if PKG_AMDGPU in TEST_PACKAGES
    import AMDGPU
    if !AMDGPU.functional() TEST_PACKAGES = filter!(x->x≠PKG_AMDGPU, TEST_PACKAGES) end
end
@static if PKG_METAL in TEST_PACKAGES
    @static if Sys.isapple()
        import Metal
        if !Metal.functional() TEST_PACKAGES = filter!(x->x≠PKG_METAL, TEST_PACKAGES) end
    else
        TEST_PACKAGES = filter!(x->x≠PKG_METAL, TEST_PACKAGES)
    end
end
@static if PKG_POLYESTER in TEST_PACKAGES
    import Polyester
end
Base.retry_load_extensions() # Potentially needed to load the extensions after the packages have been filtered.


@static for package in TEST_PACKAGES
    FloatDefault = (package == PKG_METAL) ? Float32 : Float64 # Metal does not support Float64

eval(:(
    @testset "$(basename(@__FILE__)) (package: $(nameof($package)))" begin
        $(interpolate(:__padding__, (false,), :( #TODO: change later to (false, true), when issue with CUDA not returning SubArray is fixed.
            @testset "(padding=$__padding__)" begin
                @require !@is_initialized()
                @init_parallel_stencil($package, $FloatDefault, 1, padding=__padding__)
                @require @is_initialized()
                nx  = (9,)
                A   = @IField(nx,  @rand);
                Ax  = @XField(nx,  @rand);
                Axx =  @Field(nx,  @rand);
                R   = @IField(nx, @zeros);
                Rxx =  @Field(nx, @zeros);
                @testset "1. compute macros" begin
                    @testset "differences" begin
                        @parallel d!(R, Ax) = (@all(R) = @d(Ax); return)
                        @parallel d2!(R, Axx) = (@all(R) = @d2(Axx); return)
                        R.=0; @parallel d!(R, Ax);  @test all(Array(R .== Ax[2:end].-Ax[1:end-1])) # INFO: AMDGPU arrays need to be compared on CPU
                        R.=0; @parallel d2!(R, Axx);  @test all(Array(R .== (Axx[3:end].-Axx[2:end-1]).-(Axx[2:end-1].-Axx[1:end-2])))
                    end;
                    @testset "selection" begin
                        @parallel all!(R, A) = (@all(R) = @all(A); return)
                        @parallel inn!(R, Axx) = (@all(R) = @inn(Axx); return)
                        R.=0; @parallel all!(R, A);  @test all(Array(R .== A))
                        R.=0; @parallel inn!(R, Axx);  @test all(Array(R .== Axx[2:end-1]))
                    end;
                    @testset "averages" begin
                        @parallel av!(R, Ax) = (@all(R) = @av(Ax); return)
                        R.=0; @parallel av!(R, Ax);  @test all(Array(R .== (Ax[1:end-1].+Ax[2:end]).*$FloatDefault(0.5)))
                    end;
                    @testset "harmonic averages" begin
                        @parallel harm!(R, Ax) = (@all(R) = @harm(Ax); return)
                        R.=0; @parallel harm!(R, Ax);  @test all(Array(R .== 2 ./(1 ./Ax[1:end-1].+1 ./Ax[2:end])))
                    end;
                    @testset "others" begin
                        @parallel maxloc!(R, Axx) = (@all(R) = @maxloc(Axx); return)
                        R.=0; @parallel maxloc!(R, Axx);  @test all(Array(R .== max.(max.(Axx[3:end],Axx[2:end-1]),Axx[1:end-2])))
                    end;
                end;
                @testset "2. apply masks" begin
                    @testset "selection" begin
                        @parallel inn_all!(Rxx, A) = (@inn(Rxx) = @all(A); return)
                        @parallel inn_inn!(Rxx, Axx) = (@inn(Rxx) = @inn(Axx); return)
                        Rxx.=0; @parallel inn_all!(Rxx, A);  @test all(Array(Rxx[2:end-1] .== A))
                        Rxx[2:end-1].=0; @test all(Array(Rxx .== 0))  # Test that boundary values remained zero.
                        Rxx.=0; @parallel inn_inn!(Rxx, Axx);  @test all(Array(Rxx[2:end-1] .== Axx[2:end-1]))
                        Rxx[2:end-1].=0; @test all(Array(Rxx .== 0))  # Test that boundary values remained zero.
                    end;
                    @testset "differences" begin
                        @parallel inn_d!(Rxx, Ax) = (@inn(Rxx) = @d(Ax); return)
                        @parallel inn_d2!(Rxx, Axx) = (@inn(Rxx) = @d2(Axx); return)
                        Rxx.=0; @parallel inn_d!(Rxx, Ax);  @test all(Array(Rxx[2:end-1] .== Ax[2:end].-Ax[1:end-1]))
                        Rxx[2:end-1].=0; @test all(Array(Rxx .== 0))  # Test that boundary values remained zero.
                        Rxx.=0; @parallel inn_d2!(Rxx, Axx);  @test all(Array(Rxx[2:end-1] .== (Axx[3:end].-Axx[2:end-1]).-(Axx[2:end-1].-Axx[1:end-2])))
                        Rxx[2:end-1].=0; @test all(Array(Rxx .== 0))  # Test that boundary values remained zero.
                    end;
                end;
                @reset_parallel_stencil()
            end;
        )))
    end;
))

end == nothing || true;

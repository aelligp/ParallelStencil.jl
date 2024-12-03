using Test
using ParallelStencil
import ParallelStencil: @reset_parallel_stencil, @is_initialized, SUPPORTED_PACKAGES, PKG_CUDA, PKG_AMDGPU, PKG_METAL, PKG_POLYESTER
import ParallelStencil: @require, interpolate
using ParallelStencil.FiniteDifferences2D
using ParallelStencil.FieldAllocators
import ParallelStencil.FieldAllocators: @IField, @XXYField, @XYYField
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
        $(interpolate(:__padding__, (false, true), :(
            @testset "(padding=$__padding__)" begin
                @require !@is_initialized()
                @init_parallel_stencil($package, $FloatDefault, 2, padding=__padding__)
                @require @is_initialized()
                nxy = (9, 7)
                A     =   @IField(nxy,  @rand);
                Ax    =   @XField(nxy,  @rand);
                Ay    =   @YField(nxy,  @rand);
                Axy   =  @XYField(nxy,  @rand);
                Axx   =  @XXField(nxy,  @rand);
                Ayy   =  @YYField(nxy,  @rand);
                Axyy  = @XYYField(nxy,  @rand);
                Axxy  = @XXYField(nxy,  @rand);
                Axxyy =    @Field(nxy,  @rand);
                R     =   @IField(nxy, @zeros);
                Rxxyy =    @Field(nxy, @zeros);
                @testset "1. compute macros" begin
                    @testset "differences"  begin
                        @parallel  d_xa!(R, Ax)    = (@all(R) = @d_xa(Ax); return)
                        @parallel  d_ya!(R, Ay)    = (@all(R) = @d_ya(Ay); return)
                        @parallel  d_xi!(R, Axyy)  = (@all(R) = @d_xi(Axyy); return)
                        @parallel  d_yi!(R, Axxy)  = (@all(R) = @d_yi(Axxy); return)
                        @parallel d2_xa!(R, Axx)   = (@all(R) = @d2_xa(Axx); return)
                        @parallel d2_ya!(R, Ayy)   = (@all(R) = @d2_ya(Ayy); return)
                        @parallel d2_xi!(R, Axxyy) = (@all(R) = @d2_xi(Axxyy); return)
                        @parallel d2_yi!(R, Axxyy) = (@all(R) = @d2_yi(Axxyy); return)
                        R.=0; @parallel  d_xa!(R, Ax);     @test all(Array(R .== Ax[2:end,    :].-Ax[1:end-1,      :]))
                        R.=0; @parallel  d_ya!(R, Ay);     @test all(Array(R .== Ay[    :,2:end].-Ay[      :,1:end-1]))
                        R.=0; @parallel  d_xi!(R, Axyy);   @test all(Array(R .== Axyy[2:end  ,2:end-1].-Axyy[1:end-1,2:end-1]))
                        R.=0; @parallel  d_yi!(R, Axxy);   @test all(Array(R .== Axxy[2:end-1,2:end  ].-Axxy[2:end-1,1:end-1]))
                        R.=0; @parallel d2_xa!(R, Axx);    @test all(Array(R .== (Axx[3:end,    :].-Axx[2:end-1,      :]).-(Axx[2:end-1,      :].-Axx[1:end-2,      :])))
                        R.=0; @parallel d2_ya!(R, Ayy);    @test all(Array(R .== (Ayy[    :,3:end].-Ayy[      :,2:end-1]).-(Ayy[      :,2:end-1].-Ayy[      :,1:end-2])))
                        R.=0; @parallel d2_xi!(R, Axxyy);  @test all(Array(R .== (Axxyy[3:end,2:end-1].-Axxyy[2:end-1,2:end-1]).-(Axxyy[2:end-1,2:end-1].-Axxyy[1:end-2,2:end-1])))
                        R.=0; @parallel d2_yi!(R, Axxyy);  @test all(Array(R .== (Axxyy[2:end-1,3:end].-Axxyy[2:end-1,2:end-1]).-(Axxyy[2:end-1,2:end-1].-Axxyy[2:end-1,1:end-2])))
                    end;
                    @testset "selection" begin
                        @parallel all!(R, A)     = (@all(R) = @all(A); return)
                        @parallel inn!(R, Axxyy) = (@all(R) = @inn(Axxyy); return)
                        @parallel inn_x!(R, Axx) = (@all(R) = @inn_x(Axx); return)
                        @parallel inn_y!(R, Ayy) = (@all(R) = @inn_y(Ayy); return)
                        R.=0; @parallel all!(R, A);      @test all(Array(R .== A))
                        R.=0; @parallel inn!(R, Axxyy);  @test all(Array(R .== Axxyy[2:end-1,2:end-1]))
                        R.=0; @parallel inn_x!(R, Axx);  @test all(Array(R .== Axx[2:end-1,      :]))
                        R.=0; @parallel inn_y!(R, Ayy);  @test all(Array(R .== Ayy[      :,2:end-1]))
                    end;
                    @testset "averages" begin
                        @parallel av!(R, Axy)     = (@all(R) = @av(Axy); return)
                        @parallel av_xa!(R, Ax)   = (@all(R) = @av_xa(Ax); return)
                        @parallel av_ya!(R, Ay)   = (@all(R) = @av_ya(Ay); return)
                        @parallel av_xi!(R, Axyy) = (@all(R) = @av_xi(Axyy); return)
                        @parallel av_yi!(R, Axxy) = (@all(R) = @av_yi(Axxy); return)
                        R.=0; @parallel av!(R, Axy);      @test all(Array(R .== (Axy[1:end-1,1:end-1].+Axy[2:end,1:end-1].+Axy[1:end-1,2:end].+Axy[2:end,2:end]).*$FloatDefault(0.25)))
                        R.=0; @parallel av_xa!(R, Ax);    @test all(Array(R .== (Ax[2:end,    :].+Ax[1:end-1,      :]).*$FloatDefault(0.5)))
                        R.=0; @parallel av_ya!(R, Ay);    @test all(Array(R .== (Ay[    :,2:end].+Ay[      :,1:end-1]).*$FloatDefault(0.5)))
                        R.=0; @parallel av_xi!(R, Axyy);  @test all(Array(R .== (Axyy[2:end  ,2:end-1].+Axyy[1:end-1,2:end-1]).*$FloatDefault(0.5)))
                        R.=0; @parallel av_yi!(R, Axxy);  @test all(Array(R .== (Axxy[2:end-1,2:end  ].+Axxy[2:end-1,1:end-1]).*$FloatDefault(0.5)))
                    end;
                    @testset "harmonic averages" begin
                        @parallel harm!(R, Axy)     = (@all(R) = @harm(Axy); return)
                        @parallel harm_xa!(R, Ax)   = (@all(R) = @harm_xa(Ax); return)
                        @parallel harm_ya!(R, Ay)   = (@all(R) = @harm_ya(Ay); return)
                        @parallel harm_xi!(R, Axyy) = (@all(R) = @harm_xi(Axyy); return)
                        @parallel harm_yi!(R, Axxy) = (@all(R) = @harm_yi(Axxy); return)
                        R.=0; @parallel harm!(R, Axy);      @test all(Array(R .== 4 ./(1 ./Axy[1:end-1,1:end-1].+1 ./Axy[2:end,1:end-1].+1 ./Axy[1:end-1,2:end].+1 ./Axy[2:end,2:end])))
                        R.=0; @parallel harm_xa!(R, Ax);    @test all(Array(R .== 2 ./(1 ./Ax[2:end,    :].+1 ./Ax[1:end-1,      :])))
                        R.=0; @parallel harm_ya!(R, Ay);    @test all(Array(R .== 2 ./(1 ./Ay[    :,2:end].+1 ./Ay[      :,1:end-1])))
                        R.=0; @parallel harm_xi!(R, Axyy);  @test all(Array(R .== 2 ./(1 ./Axyy[2:end  ,2:end-1].+1 ./Axyy[1:end-1,2:end-1])))
                        R.=0; @parallel harm_yi!(R, Axxy);  @test all(Array(R .== 2 ./(1 ./Axxy[2:end-1,2:end  ].+1 ./Axxy[2:end-1,1:end-1])))
                    end;
                    @testset "others" begin
                        @parallel maxloc!(R, Axxyy) = (@all(R) = @maxloc(Axxyy); return)
                        R.=0; @parallel maxloc!(R, Axxyy); @test all(Array(R .== max.(max.(max.(max.(Axxyy[1:end-2,2:end-1],Axxyy[3:end,2:end-1]),Axxyy[2:end-1,2:end-1]),Axxyy[2:end-1,1:end-2]),Axxyy[2:end-1,3:end])))
                    end;
                end;
                @testset "2. apply masks" begin
                    @testset "selection" begin
                        @parallel inn_all!(Rxxyy, A)     = (@inn(Rxxyy) = @all(A); return)
                        @parallel inn_inn!(Rxxyy, Axxyy) = (@inn(Rxxyy) = @inn(Axxyy); return)
                        Rxxyy.=0; @parallel inn_all!(Rxxyy, A);      @test all(Array(Rxxyy[2:end-1,2:end-1] .== A))
                        Rxxyy[2:end-1,2:end-1].=0;                   @test all(Array(Rxxyy .== 0))  # Test that boundary values remained zero.
                        Rxxyy.=0; @parallel inn_inn!(Rxxyy, Axxyy);  @test all(Array(Rxxyy[2:end-1,2:end-1] .== Axxyy[2:end-1,2:end-1]))
                        Rxxyy[2:end-1,2:end-1].=0;                   @test all(Array(Rxxyy .== 0))  # Test that boundary values remained zero.
                    end;
                    @testset "differences" begin
                        @parallel  inn_d_xa!(Rxxyy, Ax)     = (@inn(Rxxyy) = @d_xa(Ax); return)
                        @parallel  inn_d_yi!(Rxxyy, Axxy)   = (@inn(Rxxyy) = @d_yi(Axxy); return)
                        @parallel  inn_d2_yi!(Rxxyy, Axxyy) = (@inn(Rxxyy) = @d2_yi(Axxyy); return)
                        Rxxyy.=0; @parallel  inn_d_xa!(Rxxyy, Ax);     @test all(Array(Rxxyy[2:end-1,2:end-1] .== Ax[2:end,    :].-Ax[1:end-1,      :]))
                        Rxxyy[2:end-1,2:end-1].=0;                     @test all(Array(Rxxyy .== 0))  # Test that boundary values remained zero.
                        Rxxyy.=0; @parallel  inn_d_yi!(Rxxyy, Axxy);   @test all(Array(Rxxyy[2:end-1,2:end-1] .== Axxy[2:end-1,2:end  ].-Axxy[2:end-1,1:end-1]))
                        Rxxyy[2:end-1,2:end-1].=0;                     @test all(Array(Rxxyy .== 0))  # Test that boundary values remained zero.
                        Rxxyy.=0; @parallel inn_d2_yi!(Rxxyy, Axxyy);  @test all(Array(Rxxyy[2:end-1,2:end-1] .== (Axxyy[2:end-1,3:end].-Axxyy[2:end-1,2:end-1]).-(Axxyy[2:end-1,2:end-1].-Axxyy[2:end-1,1:end-2])))
                        Rxxyy[2:end-1,2:end-1].=0;                     @test all(Array(Rxxyy .== 0))  # Test that boundary values remained zero.
                    end;
                end;
                @reset_parallel_stencil()
            end;
        )))
    end;
))

end == nothing || true;

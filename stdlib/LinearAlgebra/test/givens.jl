# This file is a part of Julia. License is MIT: https://julialang.org/license

module TestGivens

using Test, LinearAlgebra, Random
using LinearAlgebra: Givens, Rotation, givensAlgorithm

isdefined(Main, :Quaternions) || @eval Main include(joinpath($(BASE_TEST_PATH), "testhelpers", "Quaternions.jl"))
using .Main.Quaternions

# Test givens rotations
@testset "Test Givens for $elty" for elty in (Float32, Float64, ComplexF32, ComplexF64)
    if elty <: Real
        raw_A = convert(Matrix{elty}, randn(10,10))
    else
        raw_A = convert(Matrix{elty}, complex.(randn(10,10),randn(10,10)))
    end
    @testset for A in (raw_A, view(raw_A, 1:10, 1:10))
        Ac = copy(A)
        R = Rotation(Givens{elty}[])
        T = Rotation(Givens{elty}[])
        for j = 1:8
            for i = j+2:10
                G, _ = givens(A, j+1, i, j)
                lmul!(G, A)
                rmul!(A, adjoint(G))
                lmul!(G, R)
                rmul!(T, G)

                @test lmul!(G, Matrix{elty}(I, 10, 10)) == [G[i,j] for i=1:10,j=1:10]

                @testset "transposes" begin
                    @test (@inferred G'*G)*Matrix(elty(1)I, 10, 10) ≈ Matrix(I, 10, 10)
                    @test (G*Matrix(elty(1)I, 10, 10))*G' ≈ Matrix(I, 10, 10)
                    @test (@inferred copy(R'))*(R*Matrix(elty(1)I, 10, 10)) ≈ Matrix(I, 10, 10)
                    @test_throws ErrorException transpose(G)
                    @test_throws ErrorException transpose(R)
                end
            end
        end
        @test (R')' === R
        # test products of Givens and Rotations
        for r in (R, T, *(R.rotations...), *(R.rotations[1], *(R.rotations[2:end]...)))
            @test r * A ≈ (A' * r')' ≈ lmul!(r, copy(A))
            @test A * r ≈ (r' * A')' ≈ rmul!(copy(A), r)
            @test r' * A ≈ lmul!(r', copy(A))
            @test A * r' ≈ rmul!(copy(A), r')
        end
        @test_throws ArgumentError givens(A, 3, 3, 2)
        @test_throws ArgumentError givens(one(elty),zero(elty),2,2)
        G, _ = givens(one(elty),zero(elty),11,12)
        @test_throws DimensionMismatch lmul!(G, A)
        @test_throws DimensionMismatch rmul!(A, adjoint(G))
        @test abs.(A) ≈ abs.(hessenberg(Ac).H)
        @test opnorm(R*Matrix{elty}(I, 10, 10)) ≈ one(elty)

        I10 = Matrix{elty}(I, 10, 10)
        G, _ = givens(one(elty),zero(elty),9,10)
        @test (G*I10)' * (G*I10) ≈ I10
        K, _ = givens(zero(elty),one(elty),9,10)
        @test (K*I10)' * (K*I10) ≈ I10
    end

    @testset "Givens * vectors" begin
        for x in (raw_A[:,1], view(raw_A, :, 1))
            G, r = @inferred  givens(x[2], x[4], 2, 4)
            @test (G*x)[2] ≈ r
            @test abs((G*x)[4]) < eps(real(elty))

            G, r = @inferred givens(x, 2, 4)
            @test (G*x)[2] ≈ r
            @test abs((G*x)[4]) < eps(real(elty))

            G, r = givens(x, 4, 2)
            @test (G*x)[4] ≈ r
            @test abs((G*x)[2]) < eps(real(elty))
        end
        d = rand(4)
        l = d[1]
        g2, l = givens(l, d[2], 1, 2)
        g3, l = givens(l, d[3], 1, 3)
        g4, l = givens(l, d[4], 1, 4)
        @test g2*(g3*d) ≈ g2*g3*d ≈ (g2*g3)*d
        @test g2*g3*g4 isa Rotation
    end
end

# 36430
# dimensional correctness:
const BASE_TEST_PATH = joinpath(Sys.BINDIR, "..", "share", "julia", "test")
isdefined(Main, :Furlongs) || @eval Main include(joinpath($(BASE_TEST_PATH), "testhelpers", "Furlongs.jl"))
using .Main.Furlongs

const TNumber = Union{Float64,ComplexF64}

@testset "unitful givens rotation unitful $T " for T in (Float32, Float64, ComplexF32, ComplexF64)
    g, r = givens(Furlong(T(3)), Furlong(T(4)), 1, 2)
    @test g.c.val ≈ 3/5
    @test g.c isa Furlong{0}
    @test g.s.val ≈ 4/5
    @test g.s isa Furlong{0}
    @test r.val ≈ 5.0
    @test r isa Furlong{1}
    y = g * [Furlong(T(3)), Furlong(T(4))]
    @test y[1].val ≈ r.val
    @test y[2].val ≈ 0 atol = 10eps()
end

# 51554
# avoid infinite loop on Inf inputs
@testset "givensAlgorithm - Inf inputs" for T in (Float64, ComplexF64)
    cs, sn, r = givensAlgorithm(T(Inf), T(1.0))
    @test !isfinite(r)
    cs, sn, r = givensAlgorithm(T(1.0), T(Inf))
    @test !isfinite(r)
end

@testset "givensAlgorithm with quaternions" for (x, y) in
(
    (Quaternion(randn(4)...), Quaternion(randn(4)...)),
    (0, Quaternion(randn(4)...)),
)
    c, s, r = givensAlgorithm(x, y)
    @test c * x + s * y ≈ r
    @test c * y ≈ s' * x
end

end # module TestGivens

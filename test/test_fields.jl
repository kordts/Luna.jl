import Test: @test, @testset
import Luna: Fields, FFTW, Grid, Maths, PhysData, Processing, Modes, Tools, Maths
import Statistics: mean, std
import Random: MersenneTwister

# note that most of the Fields.jl code is tested in many other modules

function getceo(t, Et, It, ω0)
    Δt = t[argmax(It)] - t[argmax(Et)]
    Δt*ω0
end

@testset "Wavelength" begin
    # real
    τfwhm = 30e-15
    λ0 = 800e-9
    energy = 1e-6
    ϕ = [0.0, 0.0]
    grid = Grid.RealGrid(1.0, λ0, (160e-9, 3000e-9), 10e-12)
    energy_t = Fields.energyfuncs(grid)[1]
    x = Array{Float64}(undef, length(grid.t))
    FT = FFTW.plan_rfft(x, 1)

    input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    @test isapprox(PhysData.wlfreq(grid.ω[argmax(abs2.(Eω))]), λ0, rtol=3e-4)
    λ0 = 320e-9
    input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    @test isapprox(PhysData.wlfreq(grid.ω[argmax(abs2.(Eω))]), λ0, rtol=3e-4)
    λ0 = 800e-9
    input = Fields.SechField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    @test isapprox(PhysData.wlfreq(grid.ω[argmax(abs2.(Eω))]), λ0, rtol=3e-4)
    λ0 = 320e-9
    input = Fields.SechField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    @test isapprox(PhysData.wlfreq(grid.ω[argmax(abs2.(Eω))]), λ0, rtol=3e-4)

    # Envelope
    τfwhm = 30e-15
    λ0 = 800e-9
    energy = 1e-6
    ϕ = [0.0, 0.0]
    grid = Grid.EnvGrid(1.0, λ0, (160e-9, 3000e-9), 10e-12)
    energy_t = Fields.energyfuncs(grid)[1]
    x = Array{ComplexF64}(undef, length(grid.t))
    FT = FFTW.plan_fft(x, 1)

    input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    @test isapprox(PhysData.wlfreq(grid.ω[argmax(abs2.(Eω))]), λ0, rtol=3e-4)
    λ0 = 320e-9
    input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    @test isapprox(PhysData.wlfreq(grid.ω[argmax(abs2.(Eω))]), λ0, rtol=3e-4)
    λ0 = 800e-9
    input = Fields.SechField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    @test isapprox(PhysData.wlfreq(grid.ω[argmax(abs2.(Eω))]), λ0, rtol=3e-4)
    λ0 = 320e-9
    input = Fields.SechField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    @test isapprox(PhysData.wlfreq(grid.ω[argmax(abs2.(Eω))]), λ0, rtol=3e-4)
end

@testset "Energy" begin
    # real
    τfwhm = 30e-15
    λ0 = 800e-9
    energy = 1e-6
    ϕ = [0.0, 0.0]
    grid = Grid.RealGrid(1.0, λ0, (160e-9, 3000e-9), 10e-12)
    energy_t = Fields.energyfuncs(grid)[1]
    x = Array{Float64}(undef, length(grid.t))
    FT = FFTW.plan_rfft(x, 1)

    input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    Et = FT \ Eω
    @test isapprox(energy_t(Et), energy, rtol=1e-14)
    
    input = Fields.SechField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    Et = FT \ Eω
    @test isapprox(energy_t(Et), energy, rtol=1e-14)

    # Envelope
    τfwhm = 30e-15
    λ0 = 800e-9
    energy = 1e-6
    ϕ = [0.0, 0.0]
    grid = Grid.EnvGrid(1.0, λ0, (160e-9, 3000e-9), 10e-12)
    energy_t = Fields.energyfuncs(grid)[1]
    x = Array{ComplexF64}(undef, length(grid.t))
    FT = FFTW.plan_fft(x, 1)

    input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    Et = FT \ Eω
    @test isapprox(energy_t(Et), energy, rtol=1e-14)

    input = Fields.SechField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    Et = FT \ Eω
    @test isapprox(energy_t(Et), energy, rtol=1e-14)
end

@testset "Duration" begin
    # real
    τfwhm = 30e-15
    λ0 = 800e-9
    energy = 1e-6
    ϕ = [0.0, 0.0]
    grid = Grid.RealGrid(1.0, λ0, (160e-9, 3000e-9), 10e-12)
    energy_t = Fields.energyfuncs(grid)[1]
    x = Array{Float64}(undef, length(grid.t))
    FT = FFTW.plan_rfft(x, 1)

    input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    Et = FT \ Eω
    It = abs2.(Maths.hilbert(Et))
    @test isapprox(Maths.fwhm(grid.t, It), τfwhm, rtol=1e-5)
    
    input = Fields.SechField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    Et = FT \ Eω
    It = abs2.(Maths.hilbert(Et))
    @test isapprox(Maths.fwhm(grid.t, It), τfwhm, rtol=1e-5)

    # Envelope
    τfwhm = 30e-15
    λ0 = 800e-9
    energy = 1e-6
    ϕ = [0.0, 0.0]
    grid = Grid.EnvGrid(1.0, λ0, (160e-9, 3000e-9), 10e-12)
    energy_t = Fields.energyfuncs(grid)[1]
    x = Array{ComplexF64}(undef, length(grid.t))
    FT = FFTW.plan_fft(x, 1)

    input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    Et = FT \ Eω
    It = abs2.(Et)
    @test isapprox(Maths.fwhm(grid.t, It), τfwhm, rtol=2e-5)

    input = Fields.SechField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    Et = FT \ Eω
    It = abs2.(Et)
    @test isapprox(Maths.fwhm(grid.t, It), τfwhm, rtol=3e-5)
end

@testset "Position" begin
    # real
    τfwhm = 30e-15
    λ0 = 800e-9
    energy = 1e-6
    τ0 = 5e-15
    # elements of ϕ are [CEP, group delay, GDD, TOD, ...]
    # so [0.0, τ0] is a delay by τ0
    ϕ = [0.0, τ0]
    grid = Grid.RealGrid(1.0, λ0, (160e-9, 3000e-9), 10e-12)
    energy_t = Fields.energyfuncs(grid)[1]
    x = Array{Float64}(undef, length(grid.t))
    FT = FFTW.plan_rfft(x, 1)

    input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    Et = FT \ Eω
    It = abs2.(Maths.hilbert(Et))
    @test isapprox(grid.t[argmax(It)], τ0, rtol=1e-15, atol=1e-15)
    
    input = Fields.SechField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    Et = FT \ Eω
    It = abs2.(Maths.hilbert(Et))
    @test isapprox(grid.t[argmax(It)], τ0, rtol=1e-15, atol=1e-15)

    # Envelope
    τfwhm = 30e-15
    λ0 = 800e-9
    energy = 1e-6
    τ0 = 5e-15
    # elements of ϕ are [CEP, group delay, GDD, TOD, ...]
    # so [0.0, τ0] is a delay by τ0
    ϕ = [0.0, τ0]
    grid = Grid.EnvGrid(1.0, λ0, (160e-9, 3000e-9), 10e-12)
    energy_t = Fields.energyfuncs(grid)[1]
    x = Array{ComplexF64}(undef, length(grid.t))
    FT = FFTW.plan_fft(x, 1)

    input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    Et = FT \ Eω
    It = abs2.(Et)
    @test isapprox(grid.t[argmax(It)], τ0, rtol=1e-15, atol=1e-15)

    input = Fields.SechField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    Et = FT \ Eω
    It = abs2.(Et)
    @test isapprox(grid.t[argmax(It)], τ0, rtol=1e-15, atol=1e-15)

    # non zero
    τ0 = -564e-15

    #real 
    τfwhm = 30e-15
    λ0 = 800e-9
    energy = 1e-6
    τ0 = 5e-15
    # elements of ϕ are [CEP, group delay, GDD, TOD, ...]
    # so [0.0, τ0] is a delay by τ0
    ϕ = [0.0, τ0]
    grid = Grid.RealGrid(1.0, λ0, (160e-9, 3000e-9), 10e-12)
    energy_t = Fields.energyfuncs(grid)[1]
    x = Array{Float64}(undef, length(grid.t))
    FT = FFTW.plan_rfft(x, 1)

    input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    Et = FT \ Eω
    It = abs2.(Maths.hilbert(Et))
    @test isapprox(grid.t[argmax(It)], τ0, rtol=1e-15, atol=1e-15)
    
    input = Fields.SechField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    Et = FT \ Eω
    It = abs2.(Maths.hilbert(Et))
    @test isapprox(grid.t[argmax(It)], τ0, rtol=1e-15, atol=1e-15)

    # Envelope
    τfwhm = 30e-15
    λ0 = 800e-9
    energy = 1e-6
    τ0 = 5e-15
    # elements of ϕ are [CEP, group delay, GDD, TOD, ...]
    # so [0.0, τ0] is a delay by τ0
    ϕ = [0.0, τ0]
    grid = Grid.EnvGrid(1.0, λ0, (160e-9, 3000e-9), 10e-12)
    energy_t = Fields.energyfuncs(grid)[1]
    x = Array{ComplexF64}(undef, length(grid.t))
    FT = FFTW.plan_fft(x, 1)

    input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    Et = FT \ Eω
    It = abs2.(Et)
    @test isapprox(grid.t[argmax(It)], τ0, rtol=1e-15, atol=1e-15)

    input = Fields.SechField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=ϕ)
    Eω = input(grid, FT)
    Et = FT \ Eω
    It = abs2.(Et)
    @test isapprox(grid.t[argmax(It)], τ0, rtol=1e-15, atol=1e-15)
end

@testset "CEO" begin
    # real
    τfwhm = 30e-15
    λ0 = 800e-9
    energy = 1e-6
    ϕCEO = 0.0
    grid = Grid.RealGrid(1.0, λ0, (160e-9, 3000e-9), 10e-12)
    energy_t = Fields.energyfuncs(grid)[1]
    x = Array{Float64}(undef, length(grid.t))
    FT = FFTW.plan_rfft(x, 1)

    input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=[ϕCEO])
    Eω = input(grid, FT)
    Et = FT \ Eω
    It = abs2.(Maths.hilbert(Et))
    @test isapprox(getceo(grid.t, Et, It, PhysData.wlfreq(λ0)), ϕCEO, rtol=1e-15, atol=1e-15)
    
    input = Fields.SechField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=[ϕCEO])
    Eω = input(grid, FT)
    Et = FT \ Eω
    It = abs2.(Maths.hilbert(Et))
    @test isapprox(getceo(grid.t, Et, It, PhysData.wlfreq(λ0)), ϕCEO, rtol=1e-15, atol=1e-15)

    # Envelope
    τfwhm = 30e-15
    λ0 = 800e-9
    energy = 1e-6
    ϕCEO = 0.0
    grid = Grid.EnvGrid(1.0, λ0, (160e-9, 3000e-9), 10e-12)
    energy_t = Fields.energyfuncs(grid)[1]
    x = Array{ComplexF64}(undef, length(grid.t))
    FT = FFTW.plan_fft(x, 1)

    input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=[ϕCEO])
    Eω = input(grid, FT)
    Et = FT \ Eω
    It = abs2.(Et)
    @test isapprox(getceo(grid.t, real(Et.*exp.(im .* grid.ω0 .* grid.t)), It, PhysData.wlfreq(λ0)), ϕCEO, rtol=1e-15, atol=1e-15)

    input = Fields.SechField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=[ϕCEO])
    Eω = input(grid, FT)
    Et = FT \ Eω
    It = abs2.(Et)
    @test isapprox(getceo(grid.t, real(Et.*exp.(im .* grid.ω0 .* grid.t)), It, PhysData.wlfreq(λ0)), ϕCEO, rtol=1e-15, atol=1e-15)

    # non zero

    #real 
    τfwhm = 30e-15
    λ0 = 800e-9
    energy = 1e-6
    τ0 = 0.0
    grid = Grid.RealGrid(1.0, λ0, (100e-9, 3000e-9), 1e-12)
    energy_t = Fields.energyfuncs(grid)[1]
    x = Array{Float64}(undef, length(grid.t))
    FT = FFTW.plan_rfft(x, 1)

    # Make CEO exact multiple of one grid point to avoid issues with argmax() in getceo()
    δt = grid.t[2] - grid.t[1]
    for i = 1:10
        ϕCEO = i*δt*PhysData.wlfreq(λ0)

        input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=[ϕCEO])
        Eω = input(grid, FT)
        Et = FT \ Eω
        It = abs2.(Maths.hilbert(Et))
        @test isapprox(abs(getceo(grid.t, Et, It, PhysData.wlfreq(λ0))), ϕCEO, rtol=1e-10)
        
        input = Fields.SechField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=[ϕCEO])
        Eω = input(grid, FT)
        Et = FT \ Eω
        It = abs2.(Maths.hilbert(Et))
        @test isapprox(abs(getceo(grid.t, Et, It, PhysData.wlfreq(λ0))), ϕCEO, rtol=1e-10)
    end

    # Envelope
    τfwhm = 30e-15
    λ0 = 800e-9
    energy = 1e-6
    τ0 = 0.0
    grid = Grid.EnvGrid(1.0, λ0, (100e-9, 3000e-9), 1e-12)
    energy_t = Fields.energyfuncs(grid)[1]
    x = Array{ComplexF64}(undef, length(grid.t))
    FT = FFTW.plan_fft(x, 1)

    # Make CEO exact multiple of one grid point to avoid issues with argmax() in getceo()
    δt = grid.t[2] - grid.t[1]

    for i = 1:10
        ϕCEO = i*δt*PhysData.wlfreq(λ0)

        input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=[ϕCEO])
        Eω = input(grid, FT)
        Et = FT \ Eω
        It = abs2.(Et)
        @test isapprox(
            abs(getceo(grid.t, real(Et.*exp.(im .* grid.ω0 .* grid.t)), It, PhysData.wlfreq(λ0))),
            ϕCEO,
            rtol=1e-10)

        input = Fields.SechField(λ0=λ0, τfwhm=τfwhm, energy=energy, ϕ=[ϕCEO])
        Eω = input(grid, FT)
        Et = FT \ Eω
        It = abs2.(Et)
        @test isapprox(
            abs(getceo(grid.t,real(Et.*exp.(im .* grid.ω0 .* grid.t)), It, PhysData.wlfreq(λ0))),
            ϕCEO,
            rtol=1e-10)
    end
end

@testset "CW fields" begin
    λ0 = 1064e-9
    Pavg = 20.0
    Δλ = 4e-9
    grid = Grid.EnvGrid(1.0, λ0, (980e-9, 1160e-9), 500e-12)
    energy_t = Fields.energyfuncs(grid)[1]
    x = Array{ComplexF64}(undef, length(grid.t))
    FT = FFTW.plan_fft(x, 1)
    input = Fields.CWSech(λ0=λ0, Pavg=Pavg, Δλ=Δλ, rng=MersenneTwister(0))
    Eω = input(grid, FT)
    Et = FT \ Eω
    I = Fields.It(Et, grid)
    istart = findfirst(isequal(1.0), grid.twin)
    iend = findlast(isequal(1.0), grid.twin)
    # test average power
    @test isapprox(mean(I[istart:iend]), Pavg, rtol=5e-16)
    # test coherence time
    @test isapprox(Processing.coherence_time(grid, Et), 3.35/(PhysData.c*(Δλ)/λ0^2*2π), rtol=1e-2)
    idcs = sortperm(PhysData.wlfreq.(grid.ω)) 
    # test spectral width
    @test isapprox(Maths.fwhm(PhysData.wlfreq.(grid.ω)[idcs], abs2.(Eω[idcs])), Δλ, rtol=3e-3)
    # now do the same for a number of realisations
    Eωs = hcat([Fields.CWSech(λ0=λ0, Pavg=Pavg, Δλ=Δλ, rng=MersenneTwister(i))(grid, FT) for i = 1:5]...)
    Iωs = abs2.(Eωs)
    Iωav = mean(Iωs, dims=2)[:,1]
    idcs = sortperm(PhysData.wlfreq.(grid.ω)) 
    # test average spectral width
    @test isapprox(Maths.fwhm(PhysData.wlfreq.(grid.ω)[idcs], Iωav[idcs], minmax=:max), Δλ, rtol=6e-4)
    Ets = FFTW.ifft(Eωs, 1)
    Its = abs2.(Ets)
    Itav = mean(Its[istart:iend,:])
    # test average power
    @test isapprox(Itav, Pavg, rtol=5e-16)
    # test diversity of power fluctuations
    @test mean(std(Its[istart:iend,:], dims=2)[:,1]) > 10
end

@testset "Propagation" begin
    λ0 = 800e-9
    τfwhm = 2.5e-15
    grid = Grid.RealGrid(1, λ0, (400e-9, 1200e-9), 500e-15)
    input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=1e-6)
    x = Array{Float64}(undef, length(grid.t))
    FT = FFTW.plan_rfft(x, 1)
    Eω = input(grid, FT)
    Eωβ1 = Fields.prop_taylor(Eω, grid, [0, 10e-15], λ0)
    Et = FT \ Eωβ1
    @test isapprox(Maths.moment(grid.t, abs2.(Maths.hilbert(Et))), 10e-15, rtol=1e-6)

    # Test sign of dispersion
    Eωβ2 = Fields.prop_taylor(Eω, grid, [0, 0, 15e-30], λ0) # positive chirp
    Et = FT \ Eωβ2
    gab = Maths.gabor(grid.t, Et, [-10e-15, 10e-15], 3e-15) # spectrogram
    ω0 = Maths.moment(grid.ω, abs2.(gab))
    @test ω0[1] < ω0[2] # mean frequency at earlier time should be lower (upchirp)

    # Test pulse stretching for Gaussian pulse
    τfwhm = 30e-15
    τ0 = Tools.τfw_to_τ0(τfwhm, :gauss)
    input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=1e-6)
    Eω = input(grid, FT)
    Eωβ2 = Fields.prop_taylor(Eω, grid, [0, 0, τ0^2], λ0) # should lead to √2 increase
    Et = FT \ Eωβ2
    τfwβ2 = Maths.fwhm(grid.t, abs2.(Maths.hilbert(Et)); method=:spline)
    τ0β2 = Tools.τfw_to_τ0(τfwβ2, :gauss)
    @test τ0β2 ≈ √2 * τ0

    # Test pulse stretching and sign of the dispersion for modal propagation
    ω0 = PhysData.wlfreq(λ0)
    # Artificial mode with τ0^2 2nd order dispersion over 2 m and α=0.1
    β(ω; z=0) = ω0/PhysData.c + 1/(0.999*PhysData.c)*(ω-ω0) + τ0^2/4*(ω-ω0)^2
    α(ω; z=0) = 0.1
    m = Modes.arbitrary(neff=Modes.neff_from_αβ(α, β))
    Eωm = copy(Eω)
    Fields.prop_mode!(Eωm, grid.ω, m, 2, λ0)
    Et = FT \ Eωm
    τfwm = Maths.fwhm(grid.t, abs2.(Maths.hilbert(Et)); method=:spline)
    τ0m = Tools.τfw_to_τ0(τfwm, :gauss)
    @test τ0m ≈ √2 * τ0
    # Check signs are correct:
    # α = 0.1 should give loss
    et, eω = Fields.energyfuncs(grid)
    @test eω(Eω)*exp(-0.2) ≈ eω(Eωm)
    # β2 > 0 should give positive chirp:
    gab = Maths.gabor(grid.t, Et, [-10e-15, 10e-15], 3e-15)
    ω0 = Maths.moment(grid.ω, abs2.(gab))
    @test ω0[1] < ω0[2]


    # Test sign of dispersion for glass
    Eωglass = Fields.prop_material(Eω, grid, :SiO2, 0.5e-3, λ0)
    Et = FT \ Eωglass
    gab = Maths.gabor(grid.t, Et, [-10e-15, 10e-15], 3e-15)
    ω0 = Maths.moment(grid.ω, abs2.(gab))
    @test ω0[1] < ω0[2]

    # Test sign of dispersion for chirped mirrors
    for mirror in (:PC70, :ThorlabsUMC)
        Eωmirr = Fields.prop_mirror(Eω, grid, mirror, 2) # one pair
        Et = FT \ Eωmirr
        gab = Maths.gabor(grid.t, Et, [-10e-15, 10e-15], 3e-15)
        ω0 = Maths.moment(grid.ω, abs2.(gab))
        @test ω0[1] > ω0[2] # negative chirp, so frequency should go down with time
    end
end

@testset "Compression" begin
# Short pulse with 100 fs^2
λ0 = 800e-9
τfwhm = 10e-15
grid = Grid.RealGrid(1, λ0, (400e-9, 1200e-9), 500e-15)
x = Array{Float64}(undef, length(grid.t))
FT = FFTW.plan_rfft(x, 1)
input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=1e-6)
Eω = input(grid, FT)
Et = FT \ Eω
Eωβ2 = Fields.prop_taylor(Eω, grid, [0, 0, 100e-30], λ0)
ϕs, Eωcomp = Fields.optcomp_taylor(Eωβ2, grid, λ0)
Etcomp = FT \ Eωcomp
@test ϕs[3] ≈ -100e-30
@test isapprox(Maths.fwhm(grid.t, abs2.(Maths.hilbert(Etcomp))), τfwhm; rtol=1e-3)

# Long pulse with 40000 fs^2 (stretches 220 fs to ~5 ps)
λ0 = 1030e-9
τfwhm = 220e-15
grid = Grid.RealGrid(1, λ0, (980e-9, 1080e-9), 20e-12)
x = Array{Float64}(undef, length(grid.t))
FT = FFTW.plan_rfft(x, 1)
input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=1e-6)
Eω = input(grid, FT)
Et = FT \ Eω
Eωβ2 = Fields.prop_taylor(Eω, grid, [0, 0, 4e-25], λ0)
ϕs, Eωcomp = Fields.optcomp_taylor(Eωβ2, grid, λ0)
Etcomp = FT \ Eωcomp
@test ϕs[3] ≈ -4e-25
@test isapprox(Maths.fwhm(grid.t, abs2.(Maths.hilbert(Etcomp))), τfwhm; rtol=1e-3)

# Short pulse with GDD and TOD
λ0 = 800e-9
τfwhm = 10e-15
grid = Grid.RealGrid(1, λ0, (400e-9, 1200e-9), 500e-15)
x = Array{Float64}(undef, length(grid.t))
FT = FFTW.plan_rfft(x, 1)
input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=1e-6)
Eω = input(grid, FT)
Et = FT \ Eω
Eωβ2 = Fields.prop_taylor(Eω, grid, [0, 0, 100e-30, 800e-45], λ0)
ϕs, Eωcomp = Fields.optcomp_taylor(Eωβ2, grid, λ0; order=3)
Etcomp = FT \ Eωcomp
@test all(ϕs .≈ [0, 0, -100e-30, -800e-45])
@test isapprox(Maths.fwhm(grid.t, abs2.(Maths.hilbert(Etcomp))), τfwhm; rtol=1e-3)

# Material insertion
λ0 = 800e-9
τfwhm = 10e-15
grid = Grid.RealGrid(1, λ0, (400e-9, 1200e-9), 500e-15)
x = Array{Float64}(undef, length(grid.t))
FT = FFTW.plan_rfft(x, 1)
input = Fields.GaussField(λ0=λ0, τfwhm=τfwhm, energy=1e-6)
Eω = input(grid, FT)
Et = FT \ Eω
EωFS = Fields.prop_material(Eω, grid, :SiO2, 2e-3, λ0)
d, Eωcomp = Fields.optcomp_material(EωFS, grid, :SiO2, λ0, -1e-2, 1e-2)
Etcomp = FT \ Eωcomp
@test d ≈ -2e-3
@test isapprox(Maths.fwhm(grid.t, abs2.(Maths.hilbert(Etcomp))), τfwhm; rtol=1e-3)
end

@testset "Gaussian beam initialisation" begin
    a = 16e-6
    gas = :Kr
    pres = 17.2
    τfwhm = 230e-15
    λ0 = 1030e-9
    energy = 5.2e-6
    modes = (
        Capillary.MarcatilliMode(a, gas, pres, n=1, m=1, kind=:HE, ϕ=0.0, loss=false),
        Capillary.MarcatilliMode(a, gas, pres, n=1, m=2, kind=:HE, ϕ=0.0, loss=false),
        Capillary.MarcatilliMode(a, gas, pres, n=1, m=3, kind=:HE, ϕ=0.0, loss=false),
        Capillary.MarcatilliMode(a, gas, pres, n=1, m=4, kind=:HE, ϕ=0.0, loss=false),
        Capillary.MarcatilliMode(a, gas, pres, n=2, m=1, kind=:HE, ϕ=0.0, loss=false),
        Capillary.MarcatilliMode(a, gas, pres, n=3, m=1, kind=:HE, ϕ=0.0, loss=false),
        Capillary.MarcatilliMode(a, gas, pres, n=0, m=1, kind=:TE, ϕ=0.0, loss=false),
        Capillary.MarcatilliMode(a, gas, pres, n=0, m=1, kind=:TM, ϕ=0.0, loss=false)
    )
    inputs = Fields.gauss_beam_init(modes, 2π/λ0, a*0.64, Fields.GaussField, λ0=λ0, τfwhm=τfwhm, energy=energy)
    inputs = (inputs..., ((mode=i, fields=(Fields.ShotNoise(),)) for i=1:length(modes))...)
    @test inputs[1].fields[1].energy/energy ≈ 0.9807131210817726
    @test inputs[2].fields[1].energy/energy ≈ 0.006182621678046407
    @test inputs[3].fields[1].energy/energy ≈ 0.0013567813790567626
    @test inputs[4].fields[1].energy/energy ≈ 0.0008447236094573648
    @test inputs[5].fields[1].energy/energy < 1e-20
    @test inputs[6].fields[1].energy/energy < 2e-20
    @test inputs[7].fields[1].energy/energy < 1e-20
    @test inputs[8].fields[1].energy/energy < 1e-20
end

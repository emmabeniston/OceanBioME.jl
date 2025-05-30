using Oceananigans.Operators: volume
using Oceananigans.Fields: _fractional_indices, _interpolate, interpolator, Center
using Oceananigans.Grids: AbstractGrid, Flat, Bounded, Periodic

@inline get_node(::Flat, i, N) = one(i)
@inline get_node(::Bounded,  i, N) = min(max(i, 1), N)
@inline get_node(::Periodic, i, N) = ifelse(i < 1, N, ifelse(i > N, 1, i))

"""
    NearestPoint

Specifies that tracer values should be taken from the nearst center point.
"""
struct NearestPoint end

@inline function extract_tracer_values(val_field_name, ::NearestPoint, particles, grid, fields, n)
    x = @inbounds particles.x[n]
    y = @inbounds particles.y[n]
    z = @inbounds particles.z[n]

    i, j, k = nearest_node(x, y, z, grid)

    field_names = required_tracers(particles)
    nf = length(field_names)

    field_values = ntuple(Val(nf)) do n
        fields[field_names[n]][i, j, k]
    end

    return field_values
end

# feels like _fractional_indices could work more intuativly
@inline collapse_position(x, y, z, ℓx, ℓy, ℓz) = (x, y, z)
@inline collapse_position(x, y, z, ::Nothing, ℓy, ℓz) = (y, z)
@inline collapse_position(x, y, z, ℓx, ::Nothing, ℓz) = (x, z)
@inline collapse_position(x, y, z, ℓx, ℓy, ::Nothing) = (x, y)
@inline collapse_position(x, y, z, ℓx, ::Nothing, ::Nothing) = (x, )
@inline collapse_position(x, y, z, ::Nothing, ℓy, ::Nothing) = (y, )
@inline collapse_position(x, y, z, ::Nothing, ::Nothing, ℓz) = (z, )

@inline function nearest_node(x, y, z, grid::AbstractGrid{FT, TX, TY, TZ}) where {FT, TX, TY, TZ}
    # messy
    ℓx = ifelse(isa(TX(), Flat), nothing, Center())
    ℓy = ifelse(isa(TY(), Flat), nothing, Center())
    ℓz = ifelse(isa(TZ(), Flat), nothing, Center())
    
    fidx = _fractional_indices(collapse_position(x, y, z, ℓx, ℓy, ℓz), grid, ℓx, ℓy, ℓz)

    ix = interpolator(fidx.i)
    iy = interpolator(fidx.j)
    iz = interpolator(fidx.k)

    i, j, k = (get_node(TX(), Int(ifelse(ix[3] < 0.5, ix[1], ix[2])), grid.Nx),
               get_node(TY(), Int(ifelse(iy[3] < 0.5, iy[1], iy[2])), grid.Ny),
               get_node(TZ(), Int(ifelse(iz[3] < 0.5, iz[1], iz[2])), grid.Nz))

    return i, j, k
end

@inline function apply_tracer_tendency!(::NearestPoint, particles, grid, particle_tendency, tendency, n)
    x = @inbounds particles.x[n]
    y = @inbounds particles.y[n]
    z = @inbounds particles.z[n]

    i, j, k = nearest_node(x, y, z, grid)

    node_volume = volume(i, j, k, grid, Center(), Center(), Center())

    atomic_add!(tendency, i, j, k, particle_tendency / node_volume)

    return nothing
end
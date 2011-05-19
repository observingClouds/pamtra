subroutine ice_ssp(f,qi,t,p,q,maxleg,kext, salb, back,  &
	nlegen, legen, legen2, legen3, legen4)
  
  use kinds
  use nml_params, only: verbose, lphase_flag
  use constants, only: pi, im

  implicit none

  integer :: numrad, nlegen, cloud_flag
  integer, intent(in) :: maxleg

  real(kind=dbl), intent(in) :: &
    qi,&
    t,&
    p,&
    q,&
    f

  real(kind=dbl) :: refre, refim

  real(kind=dbl) :: rad1, rad2, del_r, den_ice, drop_mass, iwc, ad, bd, alpha, gamma, number_concentration

  real(kind=dbl), intent(out) :: &
    kext,&
    salb,&
    back

  real(kind=dbl), dimension(200), intent(out) :: legen, legen2, legen3, legen4

  complex(kind=dbl) :: mindex

  real(kind=dbl) :: spec2abs

  if (verbose .gt. 1) print*, 'Entering ice_ssp'

    call ref_ice(t,f, refre, refim)
    mindex = refre-im*refim  ! mimicking a

if (cloud_flag .eq. 1) then
	!	Monodisperse size distribution coherent with COSMO-de 1-moment scheme
	!	Number_concentration of activated ice ctystal is temperature dependent
	!	 from COSMO-de code src_ssp.f90 routine: hydci_pp_gr
	!	Radius is derived from mass-size relation m=aD^3
	!	 a=130 kg/m^3 (hexagonal plates with aspect ratio of 0.2 -> thickness=0.2*Diameter)
	iwc = spec2abs(qi,t,p,q) 								! [kg/m^3]
	number_concentration = 1.0d2*DEXP(0.2d0*(273.15d0-t)) 	! [1/m^3]
	drop_mass = iwc/number_concentration 					! [kg]
	del_r = 1.d-8											! [m]
	rad1 = (drop_mass/130.0d0)**(1.0d0/3.0d0)				! [m]
	rad2 = rad1 + del_r
else
    ! monodisperse distribution
    ! Fixed RADIUS
	del_r = 1.d-8    ! [m]
    rad1 = 5.d-5     ! [m] 50 micron radius
    rad2 = rad1 + del_r
    den_ice = 917.d0  ! [kg/m^3]
    drop_mass = 4./3. * pi * rad1**3 * den_ice
    iwc = spec2abs(qi,t,p,q) ! [kg/m^3]
endif

    ad = iwc/(drop_mass*del_r) 	!intercept parameter [1/m^4]
    bd = 0.0d0 
    alpha = 5.0d0     ! exponential SD
    gamma = 1.0d0 
    numrad = 2 

    call mie(f, mindex, rad1, rad2, numrad, maxleg, ad,    &
	  bd, alpha, gamma, lphase_flag, kext, salb, back,     &
	  nlegen, legen, legen2, legen3, legen4, 'C')
  if (verbose .gt. 1) print*, 'Exiting ice_ssp'

  return

end subroutine ice_ssp

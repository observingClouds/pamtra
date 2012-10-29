subroutine radar_simulator(particle_spectrum,back,frequency,temp,&
      nz,nx,ny,fi)!, &
!   spectra_velo, noise_turb_spectra, snr_turb_spectra)
!nbins: No of bins + 1
!diameter_spec: Diameter Spectrum (SI)
!qback_spec: backscattering cross section in 1/m
!the reflectivity of all hydrometeors in 1/m
!particle_type: cl cloud|
!frequency, frequency [GHz]

  use kinds
  use nml_params
  use constants
  use vars_output, only: radar_spectra, radar_snr, radar_vel !output of the radar simulator
  implicit none
  
  integer, parameter :: maxTurbTerms=500


  real(kind=dbl),intent(in) ::  frequency, temp, back
  integer,intent(in) ::  nz,nx,ny,fi
  real(kind=dbl), dimension(radar_nfft),intent(in):: particle_spectrum



  real(kind=dbl), dimension(maxTurbTerms):: turb
  real(kind=dbl), dimension(radar_nfft*radar_no_Ave):: x_noise
  real(kind=dbl), dimension(radar_no_Ave,radar_nfft):: noise_turb_spectra_tmp
  real(kind=dbl), dimension(radar_nfft):: noise_turb_spectra,&
      snr_turb_spectra,spectra_velo !,intent(out)
  real(kind=dbl), dimension(:),allocatable:: turb_spectra
  real(kind=dbl):: SNR, del_v, ss, K2, wavelength, Ze_back, dielec_water
  integer :: ii, tt, turbLen,alloc_status,ts_imin, ts_imax

  ! get |K|**2 and lambda
  K2 = dielec_water(0.D0,temp-t_abs,frequency)
  wavelength = c / (frequency*1.d9)   ! [m]

  !transform backscattering in linear reflectivity units, 10*log10(back) would be in dBz
  Ze_back = 1.d18* (1.d0/ (K2*pi**5) ) * back * (wavelength)**4 *0.5 ![mm⁶/m³] !@Pavlos why /2????
print*,10*log10(Ze_back)
  !get delta velocity
  del_v = (radar_max_V-radar_min_V)/radar_nfft ![m/s]
  !create array from min_v to max_v iwth del_v spacing -> velocity spectrum of radar
  spectra_velo = (/(((ii*del_v)+radar_min_V),ii=0,radar_nfft)/) ! [m/s]
  
  !get turbulence
  ss = radar_turbulence_st/del_v; !in array indices!

  tt = 1
  do while (tt .le. 6.d0/del_v+1.d0) 
    if (tt .gt. maxTurbTerms) then
      print*,tt, 6.d0/del_v+1.d0, ": maximum of turbulence terms reached. increase maxTurbTerms (radar_spectrum.f90)"
      stop
    end if
    !
    turb(tt) = 1.d0/(sqrt(2.d0*pi)*ss) * exp(-(tt-(3.d0/del_v+1.d0))**2.d0/(2.d0*ss**2.d0))
    tt = tt+1
  end do

  turbLen=tt-1

  if (SIZE(particle_spectrum)+turbLen-1 .lt. floor(3/del_v+1)+radar_nfft-1) then
    print*, SIZE(particle_spectrum)+turbLen-1,floor(3/del_v+1)+radar_nfft-1,&
	"vector resulting from convolution to short!  (radar_spectrum.f90)"
    stop
  end if

  allocate(turb_spectra(SIZE(particle_spectrum)+turbLen-1),stat=alloc_status)

  !convolute spectrum and noise
  call convolution(particle_spectrum,SIZE(particle_spectrum),turb(1:turbLen),turbLen,turb_spectra)

  !I don't like Nans here'
  where(ISNAN(turb_spectra)) turb_spectra = 0.d0

  ts_imin = floor(3/del_v+1)
  ts_imax = floor(3/del_v+1)+radar_nfft-1
  SNR = 10.d0*log10(Ze_back/radar_Pnoise)

  snr_turb_spectra = ((Ze_back/SUM(turb_spectra(ts_imin:ts_imax)*del_v))*&
      turb_spectra(ts_imin:ts_imax) + radar_pnoise/(radar_nfft*del_v))

  !init_random_seed works with system clock, so if called very often it creates the same random numbers. Thus, create a big one now
  call init_random_seed()
  call RANDOM_NUMBER(x_noise)

  do tt = 1, radar_no_Ave
    noise_turb_spectra_tmp(tt,:) = -log(x_noise((tt-1)*radar_nfft+1:tt*radar_nfft))*snr_turb_spectra
  end do

  
  if (radar_no_Ave .eq. 1) then
    noise_turb_spectra = noise_turb_spectra_tmp(1,:)
  else
    noise_turb_spectra = SUM(noise_turb_spectra_tmp,DIM=1)/radar_no_Ave
  end if

  radar_spectra(nx,ny,nz,fi,:) = 10*log10(noise_turb_spectra(:))
  radar_snr(nx,ny,nz,fi) = SNR
  radar_vel(:) = spectra_velo(:)

deallocate(turb_spectra)
  return
end subroutine radar_simulator
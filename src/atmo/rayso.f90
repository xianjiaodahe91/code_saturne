!-------------------------------------------------------------------------------

! This file is part of Code_Saturne, a general-purpose CFD tool.
!
! Copyright (C) 1998-2018 EDF S.A.
!
! This program is free software; you can redistribute it and/or modify it under
! the terms of the GNU General Public License as published by the Free Software
! Foundation; either version 2 of the License, or (at your option) any later
! version.
!
! This program is distributed in the hope that it will be useful, but WITHOUT
! ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
! FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
! details.
!
! You should have received a copy of the GNU General Public License along with
! this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
! Street, Fifth Floor, Boston, MA 02110-1301, USA.

!-------------------------------------------------------------------------------
!> \file rayso.f90
!> \brief 1D Radiative scheme - Solar flux
!
!> \brief This program computes solar fluxes for both clear and cloudy
!>      atmosphere following Lacis and Hansen, 1974
!>   - the multiple diffusion is taken into account by adding method and
!>     overlapping between water vapor and liquid water
!>      with k distribution method
!>     Some improvments from original version concerns:
!>     - introduction of cloud fraction with hazardeous recovering
!>     - introduction of aerosol diffusion on the same way than cloud droplets
!>       but with specific optical properties for aerosols
!>
!-------------------------------------------------------------------------------
! Arguments
!______________________________________________________________________________.
!  mode           name          role
!______________________________________________________________________________!
!> \param[in]   k1          index for ground level
!> \param[in]   kmray       vertical levels number for radiation
!> \param[in]   heuray      Universal time (Hour)
!> \param[in]   imer1       sea index
!> \param[in]   albe        albedo
!> \param[in]   qqv         optical depth for water vapor (0,z)
!> \param[in]   qqqv        idem for intermediate levels
!> \param[in]   qqvinf      idem qqv but for altitude above 11000m
!> \param[in]   zqq         vertical levels
!> \param[in]   zray        altitude (physical mesh)
!> \param[in]   qvray       specific umidity for water vapor
!> \param[in]   qlray       specific humidity for liquid water
!> \param[in]   fneray      cloud fraction
!> \param[in]   romray      air density
!> \param[in]   aeroso      aerosol concentration in micro-g/m3
!> \param[out]  fos         global downward solar flux at the ground
!> \param[out]  rayst       flux divergence of solar radiation
!_______________________________________________________________________________

subroutine rayso  &
 (k1, kmray, heuray, imer1, albe,                &
  qqv, qqqv, qqvinf, zqq,                        &
  zray, qvray, qlray, fneray,                    &
  romray, aeroso, fos, rayst)

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use optcal
use cstphy
use entsor
use parall
use period
use ppppar
use ppthch
use ppincl
use atincl, only: kmx, nbmett, squant, xlat, xlon, cpvcpa

!===============================================================================

implicit none

! Arguments

integer k1,kmray,imer1
double precision albe,heuray,fos
double precision qqv(kmx+1), qqqv(kmx+1), qqvinf, zqq(kmx+1)
double precision qlray(kmx),fneray(kmx),zray(kmx)
double precision qvray(kmx)
double precision aeroso(kmx)
double precision rayst(kmx),romray(kmx)

! Local variables

integer i,k,n,l,inua,k1p1,iaer
integer itop,ibase,itopp1,itopp2,ibasem1
double precision muzero,fo,rr1,m,mbar,rabar,rabar2,rbar
double precision rabarc,rabar2c,rbarc
double precision qqvtot,ym1,y,ystarm1,ystar
double precision zqm1,zq,xm1,x,xstar,xstarm1,fabs
double precision rrbar,rrbar2s,foo3,foo3c,foh2o
double precision tauctot,wh2ol,rm,req,deltaz
double precision extlnp,extlnm,pioc,zbas,dud1
double precision gasym,drt,tln,drtt1,dtrb1
double precision kn(8),pkn(8),dowtot1,dqqv
double precision zaero,reaero,piaero,gaero,caero
double precision cphum,qureel
double precision waero,taua(kmx+1),tauatot
double precision rabara,rabar2a,rbara,raero
double precision niaer,nraer
double precision s3,gama1,gama2,kt,gas,fas

double precision, allocatable:: fabsh2o(:),fabso3(:),tauc(:)
double precision, allocatable:: tau(:,:),pic(:,:),ref(:,:)
double precision, allocatable:: reft(:,:),trat(:,:),refts(:,:)
double precision, allocatable:: refs(:,:),tras(:,:),trats(:,:)
double precision, allocatable:: refb(:,:),trab(:,:),upw(:,:)
double precision, allocatable:: refbs(:,:),fabso3c(:,:),tra(:,:)
double precision, allocatable:: dow(:,:),atln(:,:),absn(:,:)
double precision, allocatable:: fnebmax(:),fneba(:)

! data pour la distribution pkn et kn

data kn/4.d-5,0.002,0.035,0.377,1.95,9.40,44.6,190./
data pkn/0.6470,0.0698,0.1443,0.0584,0.0335,0.0225,0.0158,0.0087/

!========================================================================

allocate(fabsh2o(kmx+1),fabso3(kmx+1),tauc(kmx+1))
allocate(tau(kmx+1,8),pic(kmx+1,8),ref(kmx+1,8))
allocate(reft(kmx+1,8),trat(kmx+1,8),refts(kmx+1,8))
allocate(refs(kmx+1,8),tras(kmx+1,8),trats(kmx+1,8))
allocate(refb(kmx+1,8),trab(kmx+1,8),upw(kmx+1,8))
allocate(refbs(kmx+1,8),fabso3c(kmx+1,2),tra(kmx+1,8))
allocate(dow(kmx+1,8),atln(kmx+1,8),absn(kmx+1,8))
allocate(fnebmax(kmx+1),fneba(kmx+1))

!     1 - local initializations
!     ===========================

inua = 0
iaer = 0
ibase = 0

do k = 1,kmray
  if(qlray(k).gt.1.d-8.or.aeroso(k).gt.1.d-8) inua = 1
  if(aeroso(k).gt.1.d-10) iaer = 1
enddo

do k = 1, kmx+1
  fabsh2o(k) = 0.d0
  fabso3(k) = 0.d0
  tauc(k) = 0.d0
  taua(k) = 0.d0
  fnebmax(k) = 0.d0
  if(iaer.ge.1) then
    fneba(k) = 1.d0
  endif
  do l = 1, 2
    fabso3c(k,l) = 0.d0
  enddo
  do l = 1, 8
    tau(k,l) = 0.d0
    pic(k,l) = 0.d0
    atln(k,l) = 0.d0
    absn(k,l) = 0.d0
    ref(k,l) = 0.d0
    reft(k,l) = 0.d0
    refts(k,l) = 0.d0
    refs(k,l) = 0.d0
    refb(k,l) = 0.d0
    refbs(k,l) = 0.d0
    trat(k,l) = 0.d0
    tras(k,l) = 0.d0
    trab(k,l) = 0.d0
    trats(k,l) = 0.d0
    tra(k,l) = 0.d0
    upw(k,l) = 0.d0
    dow(k,l) = 0.d0
  enddo
enddo

!  data for aerosol characteristics
!  (aerosols depth, radius, single scattering albedo, refraction indexes)
zaero  = 11000.d0
raero  = 0.1d0
! Leighton 1980
! (M.Tombette 2008   piaero = 0.92)
piaero = 0.84d0

gaero  = 0.66d0
nraer  = 1.55d0
niaer  = 0.01d0

! constant for units (use caero = 0. to cancel aerosol effects)
caero = 1.d-9

k1p1 = k1+1

!  2 - calculation for muzero and solar constant fo
!  ===================================================
!        muzero = cosin of zenithal angle
!        fo = solar constant in watt/m2

!
!  careful : 0. h < heuray < 24. h
!  ---------

qureel = float(squant)
call raysze(xlat,xlon,qureel,heuray,imer1,albe,muzero,fo)
! if muzero is negative, it is night and solar radiation is not
! computed

if(muzero.gt.0.d0) then

! correction for very low zenithal angles

  rr1 = 0.1255d-2
  muzero = rr1/(sqrt(muzero**2 + rr1*(rr1 + 2.d0)) - muzero)
  m = 35.d0/sqrt(1224.d0*muzero*muzero + 1.d0)
  mbar = 1.9d0

!  3 -  albedoes for O3 and Rayleigh diffusion
!  ==================================================================
  rabar = 0.219d0/(1.d0 + 0.816d0*muzero)
  rabar2 = 0.144d0
  rbar = rabar + (1.d0 - rabar)*(1.d0 - rabar2)*albe/(1.d0 - rabar2*albe)
  rrbar = 0.28d0/(1.d0 + 6.43d0*muzero)
  rrbar2s = 0.0685d0

!  4 - addition of one level for solar radiation
!  ========================================================
  zqq(kmray+1) = 16000.d0
  qqvtot = qqvinf + qqqv(kmray)
  qqv(kmray+1) = qqvtot - qqvinf/4.d0

! testing the presence of clouds or aerosols
  if((inua.eq.0).and.(iaer.eq.0)) then
!   5 -  solar radiatiobn calculation for clear atmosphere
!       (without clouds and aerosols)
!============================================================================

! solar heating in the vertical layers for clear sky

    rayst(k1) = 0.d0

! for water vapor
! in that case we use optical depth that has been calculated  for IR radiation

    do i = k1p1, kmray
      ym1 = m*(qqvtot - qqv(i))
      if(i.eq.k1p1) ym1 = m*qqvtot
      y = m*(qqvtot - qqv(i+1))
      ystarm1 = m*qqvtot + 5.d0/3.d0*qqv(i)
      if(i.eq.k1p1) ystarm1 = m*qqvtot
      ystar = m*qqvtot + 5.d0/3.d0*qqv(i+1)
      fabsh2o(i) = muzero*fo*(raysve(ym1) - raysve(y) + albe*(raysve(ystar)   &
                 - raysve(ystarm1)))

! for O3

      zqm1 = zqq(i)
      zq = zqq(i+1)
      if(i.eq.k1p1) zqm1 = zray(k1)
      xm1 = m*rayuoz(zqm1)
      x = m*rayuoz(zq)
      zbas = zray(k1)
      xstarm1 = m*rayuoz(zbas) + mbar*(rayuoz(zbas) - rayuoz(zqm1))
      xstar = m*rayuoz(zbas) + mbar*(rayuoz(zbas) - rayuoz(zq))
      fabso3(i) = muzero*fo*(raysoz(xm1) - raysoz(x) + rbar                  &
                 *(raysoz(xstar) - raysoz(xstarm1)))

! total heating

      fabs = fabsh2o(i) + fabso3(i)
      cphum = cp0*(1.d0 + (cpvcpa - 1.d0)*qvray(i))
      rayst(i) = fabs/romray(i)/cphum/(zq-zqm1)

    enddo

! global downward radiation flux at the ground

    foo3 = muzero*fo*(0.647d0 - rrbar - raysoz(m*rayuoz(zbas)))*             &
         (1.d0 - albe)/(1.d0 - rrbar2s*albe)
    foh2o = muzero*fo*(0.353d0 - raysve(m*qqvtot))*(1.d0 - albe)

    fos = foh2o + foo3

  else

!     6 - Solar radiation calculation for cloudy sky
!     In order to take into account cloud fraction, multiple diffusion is achieved for
!     both cloudy (index 1) and clear (index 2) sky

!============================================================================

!  6.1 cloud level determination (top for the ttpo of the higher cloud,
!  base for the bottom of the lower cloud)
!      ........    .........................................................

    itop = 0

    do i = kmray, k1p1, -1
      if(qlray(i).gt.1.d-8.or.aeroso(i).gt.1.d-5) then
        if(itop.eq.0) then
          itop = i
          ibase = i
        else
          ibase = i
        endif
      endif
    enddo

! if itop = 0, there is no cloud but, nevertheless, it is possible to execute
! the adding method

    if(itop.eq.0) then
      itop = k1
      ibase = k1
    endif
    itopp1 = itop +1
    itopp2 = itop +2
    ibasem1 = ibase -1

! 6.2 calculation for optical oparmaters of clouds
! (single scattering albedo, optical depth)
!     .........    .....................................................

    fnebmax(kmray+1) = 0.d0
    tauctot = 0.d0
    tauatot = 0.d0
    do i = kmray, k1p1, -1
      if((i.ge.ibasem1).and.(i.le.itopp1)) then
! liquid water density in g/m3 in the layers
        wh2ol = 1.d3*(romray(i)*qlray(i))! + aeroso(i)
! mean droplet radius in µm
        rm = 30.d0*wh2ol + 2.d0
!  the max of the mean radius is fixed at 10 µ in the considered domain
!  and at 2 µ above
        if(i.le.nbmett) then
          rm = min(10.d0,rm)
        else
          rm = min(2.d0,rm)
        endif
        req = 3.d0*rm/2.d0
        deltaz = zqq(i+1) - zqq(i)
        if(i.eq.k1p1) deltaz = zqq(i+1) - zray(k1)
! req has to be in µm
        tauc(i) = 1.5d0*wh2ol*deltaz/req
        tauctot = tauctot + tauc(i)
      else
        tauc(i) = 0.d0
      endif

! calculation for aerosol optical parameters treated as cloud layers but with
! different optical properties

      fneba(i) = 0.d0
      if((iaer.eq.1).and.(zray(i).le.zaero)) then
        fneba(i) = 1.d0
        waero = 1.e3*romray(i)*caero*aeroso(i)
        deltaz = zqq(i+1) - zqq(i)
        if(i.eq.k1p1) deltaz=zqq(i+1) - zray(k1)
! reaero has to be in µm
        reaero = 3.d0*raero/2.d0
        taua(i) = 1.5d0*waero*deltaz/reaero
        tauatot = tauatot + taua(i)
      endif
! estimation of the maw of the cloud fraction

      fnebmax(i) = max(fnebmax(i+1),fneray(i))
    enddo

    fnebmax(k1) = fnebmax(k1p1)

! single scattering albedo for all cloud layers
!    ( for pure water pioc=1)
    pioc = 0.9988d0
    tauc(kmray+1) = 0.d0

! 6.3 O3 absorption in presence of clouds
!     .........    ...............................................

! calculation of the different albedoes for O3 (Stephens, 74)

! assymetric factor for liquid water

    gasym = 0.85d0

    s3 = sqrt(3.d0)
    rabarc = s3*(1.d0 - gasym)*tauctot/(2.d0 + s3*(1.d0 - gasym)*tauctot)
    rabar2c = rabarc
    rbarc = rabarc + (1.d0 - rabarc)*(1.d0 - rabar2c)*albe/(1.d0 - rabar2c*albe)
    rabara = s3*(1.d0 - gaero)*tauatot/(2.d0 + s3*(1.d0 - gaero)*tauatot)
    rabar2a = rabara
    rbara = rabara + (1.d0 - rabara)*(1.d0 - rabar2a)*albe/(1.d0 - rabar2a*albe)

! In the case were the sky is totaly cloudy, the absorption is computed
! only for the layers above cloud top

!
! the absorption is computed with  weighting the fluxes by using the max
! of the cloud fraction
! calculation above the top of the cloud
    do i = itop, kmray

      zqm1 = zqq(i)
      if(i.eq.k1p1) zqm1 = zray(k1)
      zq = zqq(i+1)
      xm1 = m*rayuoz(zqm1)
      x = m*rayuoz(zq)
! cloudy sky
      zbas = zray(itop)
      xstarm1 = m*rayuoz(zbas) + mbar*(rayuoz(zbas) - rayuoz(zqm1))
      xstar = m*rayuoz(zbas) + mbar*(rayuoz(zbas) - rayuoz(zq))
      fabso3c(i,1) = muzero*fo*(fnebmax(i-1)*                                &
                   (raysoz(xm1) - raysoz(x))                                 &
                   + fnebmax(k1p1)*rbarc*(raysoz(xstar) - raysoz(xstarm1)))

!  clear sky
      zbas = zray(k1)
      xstarm1 = m*rayuoz(zbas) + mbar*(rayuoz(zbas) - rayuoz(zqm1))
      xstar = m*rayuoz(zbas) + mbar*(rayuoz(zbas) - rayuoz(zq))
      fabso3c(i,2) = muzero*fo*((1.d0 - fnebmax(i-1))*                        &
                     (raysoz(xm1) - raysoz(x))                                &
                   + (1.d0 - fnebmax(k1p1))*rbar                              &
                   * (raysoz(xstar) - raysoz(xstarm1)))

!  Aerosols are taking into account in the clear sky calculations
! with  aerosol fraction = 1
      if((iaer.eq.1).and.(zqm1.gt.zaero)) then
        zbas = zaero
        xstarm1 = m*rayuoz(zbas) + mbar*(rayuoz(zbas) - rayuoz(zqm1))
        xstar = m*rayuoz(zbas) + mbar*(rayuoz(zbas) - rayuoz(zq))
        fabso3c(i,2) = muzero*fo*((1.d0 - fnebmax(i-1))*                        &
                       (raysoz(xm1) - raysoz(x))                                &
                     + (1.d0 - fnebmax(k1p1))*rbara                             &
                     *(raysoz(xstar) - raysoz(xstarm1)))
      endif

      if((iaer.eq.1).and.(zqm1.le.zaero)) then
        x = m*rayuoz(zaero)
        xstar = m*rayuoz(zaero)
        fabso3c(i,2) = 0.d0
      endif

      fabso3(i) = fabso3c(i,1) + fabso3c(i,2)

    enddo
! calculation under the top of the cloud
!

    do i = k1p1, itop-1

!  cloudy sky
      fabso3c(i,1) = 0.d0
!  clear sky
      zqm1 = zqq(i)
      if(i.eq.k1p1) zqm1 = zray(k1)
      zq = zqq(i+1)
      xm1 = m*rayuoz(zqm1)
      x = m*rayuoz(zq)
      zbas = zray(k1)
      xstarm1 = m*rayuoz(zbas) + mbar*(rayuoz(zbas) - rayuoz(zqm1))
      xstar = m*rayuoz(zbas) + mbar*(rayuoz(zbas) - rayuoz(zq))
      fabso3c(i,2) = muzero*fo*((1.d0 - fnebmax(i-1))*                        &
                     (raysoz(xm1) - raysoz(x))                                &
                   + (1.d0-fnebmax(k1p1))*rbar                                &
                   * (raysoz(xstar)-raysoz(xstarm1)))

      if((iaer.eq.1).and.(zqm1.gt.zaero)) then
        zbas = zaero
        xstarm1 = m*rayuoz(zbas) + mbar*(rayuoz(zbas) - rayuoz(zqm1))
        xstar = m*rayuoz(zbas) + mbar*(rayuoz(zbas) - rayuoz(zq))
        fabso3c(i,2) = muzero*fo*((1.d0 - fnebmax(i-1))*                     &
                     (raysoz(xm1) - raysoz(x))                               &
                     + (1.d0 - fnebmax(k1p1))*rbara                          &
                     * (raysoz(xstar) - raysoz(xstarm1)))
      endif

      if((iaer.eq.1).and.(zqm1.le.zaero)) then
        x = m*rayuoz(zaero)
        xstar = m*rayuoz(zaero)
        fabso3c(i,2) = 0.d0
      endif

      fabso3(i) = fabso3c(i,1) + fabso3c(i,2)
    enddo

! 6.4 Absorption by water vapor and liquid water
!     .........    ...................................................

! In that case we have to solve multiple diffusion. This is achieved by means
! of the adding method following Lacis et Hansen, 1974

! calculation of reflexivity and tarnsmissivity for each vertical layer
    do n = 1, 8
      do l = k1p1, kmray
        dqqv = kn(n)*(qqv(l+1) - qqv(l))/10.d0
        if(l.eq.k1p1) dqqv = kn(n)*qqv(l+1)/10.d0
! cloudy sky
        tau(l,n) = tauc(l) + dqqv + taua(l)
        if(tauc(l).ne.0.) then
          pioc = 0.9988d0
          pic(l,n) = (pioc*tauc(l) + piaero*taua(l))/tau(l,n)
          gas = (pioc*tauc(l)*gasym + piaero*taua(l)*gaero)               &
              /(pic(l,n)*tau(l,n))
! Joseph, 1976 correction for very low zenithal angle
          fas = gas*gas
          tau(l,n) = (1.d0 - pic(l,n)*fas)*tau(l,n)
          pic(l,n) = pic(l,n)*(1.d0 - fas)/(1.d0 - pic(l,n)*fas)
          gas = (gas - fas)/(1.d0 - fas)

          gama1 = (s3/2.d0)*(2.d0 - pic(l,n)*(1.d0 + gas))
          gama2 = (s3*pic(l,n)/2.d0)*(1.d0 - gas)
          kt = sqrt(gama1*gama1 - gama2*gama2)
          tln = kt*tau(l,n)
          extlnp = exp(tln)
          extlnm = exp(-tln)
          drt = (kt + gama1)*extlnp + (kt-gama1)*extlnm
          ref(l,n) = fneray(l)*gama2*(extlnp - extlnm)/drt
          tra(l,n) = fneray(l)*2.d0*kt/drt                                &
                    + (1.d0 - fneray(l))*exp(-5.d0*dqqv/3.d0)

!  trard transmissivity for direct radiation
          refs(l,n) = ref(l,n)
          tras(l,n) = tra(l,n)
        else
! in the clear sky layers
          ref(l,n) = 0.d0
          tra(l,n) = exp(-5.d0*tau(l,n)/3.d0)
          refs(l,n) = ref(l,n)
          tras(l,n) = tra(l,n)
          if(l.ge.itopp1) tra(l,n) = exp(-m*tau(l,n))
! in the aerosol layers
          if((iaer.eq.1).and.(zray(l).le.zaero)) then
            tau(l,n) = taua(l) + dqqv
            pioc = piaero
            pic(l,n) = pioc*taua(l)/tau(l,n)
            gas = gaero
! Joseph, 1976 correction for very low zenithal angle
            fas = gas*gas
            tau(l,n) = (1.d0 - pic(l,n)*fas)*tau(l,n)
            pic(l,n) = pic(l,n)*(1.d0 - fas)/(1.d0 - pic(l,n)*fas)
            gas = (gas - fas)/(1.d0 - fas)
            gama1 = (s3/2.d0)*(2.d0 - pic(l,n)*(1.d0 + gas))
            gama2 = (s3*pic(l,n)/2.d0)*(1.d0 - gas)
            kt = sqrt(gama1*gama1 - gama2*gama2)
            tln = kt*tau(l,n)
            extlnp = exp(tln)
            extlnm = exp(-tln)
            drt = (kt+gama1)*extlnp + (kt - gama1)*extlnm
            ref(l,n) = fneba(l)*gama2*(extlnp - extlnm)/drt
            tra(l,n) = fneba(l)*2.d0*kt/drt                                &
                     + (1.d0 - fneba(l))*exp(-5.d0*dqqv/3.d0)
          endif
        endif

      enddo
! boundary conditions at the top of the atmosphere

      tau(kmray+1,n) = kn(n)*qqvinf/40.d0
      tra(kmray+1,n) = exp(-m*tau(kmray+1,n))
      ref(kmray+1,n) = 0.d0
      tras(kmray+1,n) = tra(kmray+1,n)
      refs(kmray+1,n) = ref(kmray+1,n)
      tra(k1,n) = 0.d0
      ref(k1,n) = albe
      tras(k1,n) = 0.d0
      refs(k1,n) = 0.d0

! downward addition of layers

      trat(kmray+1,n) = tra(kmray+1,n)
      reft(kmray+1,n) = ref(kmray+1,n)
      refts(kmray+1,n) = refs(kmray+1,n)
      trats(kmray+1,n) = tras(kmray+1,n)
      fneray(k1) = 0.d0

      do l = kmray, k1, -1
        drtt1 = 1.d0 - refts(l+1,n)*ref(l,n)
        reft(l,n) = reft(l+1,n)                                          &
                  + trat(l+1,n)*ref(l,n)*trats(l+1,n)/drtt1
        trat(l,n) = trat(l+1,n)*tra(l,n)/drtt1
        if(l.gt.k1) then
          refts(l,n) = refs(l,n)                                         &
                     + tras(l,n)*refts(l+1,n)*tra(l,n)/drtt1
          trats(l,n) = trats(l+1,n)*tras(l,n)/drtt1
        endif
      enddo

! upward layer addition
      refb(k1,n) = ref(k1,n)
      refbs(k1,n) = refs(k1,n)

      do l = k1p1, kmray
        dtrb1 = 1.d0 - refb(l-1,n)*refs(l,n)
        refb(l,n) = ref(l,n) + tra(l,n)*refb(l-1,n)*tras(l,n)/dtrb1
      enddo

! calculation of downward and upward fluxes

      do l = kmray+1, k1p1, -1
        dud1 = 1.d0 - refts(l,n)*refb(l-1,n)
        upw(l,n) = trat(l,n)*refb(l-1,n)/dud1
        dow(l,n) = trat(l,n)/dud1

! downward fluxes for direct radiation

! the absorption is computed by weighting the downward and upward fluxes
! contribution by the max of the cloud fraction between infinite and z

        atln(l,n) = pkn(n)*((1.d0 - reft(k1,n)) + upw(l,n)              &
                  - dow(l,n))
      enddo

! absorption in individual layers

      do l = kmray, k1p1, -1
        absn(l,n) = atln(l,n) - atln(l+1,n)
      enddo

    enddo

! summation over frequencies and estimation of absorption integrated
!  on the whole spectrum


    do l = kmray, k1p1, -1
      fabsh2o(l) = 0.d0
      do n = 1, 8
        fabsh2o(l) = fabsh2o(l)+absn(l,n)
      enddo
      fabsh2o(l) = fabsh2o(l)*fo*muzero
    enddo


! 6.5 heating in the layers
!     .........    ...............................

    rayst(k1) = 0.d0
    do i = k1p1, kmray
      deltaz = zqq(i+1) - zqq(i)
      if(i.eq.k1p1) deltaz = zqq(i+1) - zray(k1)
      cphum = cp0*(1.d0 + (cpvcpa - 1.d0)*qvray(i))
      rayst(i) = (fabsh2o(i) + fabso3(i))/deltaz/romray(i)/cphum
    enddo

! 6.6 calculation of downward solar flux with weighting by cloud fraction
!     .........    .................................................
! f for global radiatiojn, fd for direct radiation

    dowtot1 = 0.d0
    do n = 2, 8
      dowtot1 = dowtot1 + pkn(n)*dow(k1p1,n)
    enddo
    foh2o = fo*muzero*(1.d0 - albe)*dowtot1
    foo3c = fo*muzero*(0.647d0 - rrbar - raysoz(m*rayuoz(zray(itop))))      &
           *(1.d0 - rabarc)*(1.d0 - albe)/(1.d0 - rabarc*albe)
    foo3 = muzero*fo*(0.647d0 - rrbar - raysoz(m*rayuoz(zbas)))             &
           *(1.d0 - albe)/(1.d0 - rrbar2s*albe)

    if(iaer.ne.0.d0) then
      foo3 = fo*muzero*(0.647d0 - rrbar - raysoz(m*rayuoz(zaero)))          &
          *(1.d0 - rabara)*(1.d0 - albe)/(1.d0 - rabara*albe)
    endif

    foo3 = foo3c*fnebmax(k1p1) + foo3*(1.d0 - fnebmax(k1p1))
    fos = foh2o + foo3

  endif


! if muzero < 0, it is night
else

  muzero = 0.d0
  do k = k1, kmray
    rayst(k) = 0.d0
  enddo

endif

deallocate(fabsh2o,fabso3,tauc)
deallocate(tau,pic,ref)
deallocate(reft,refts)
deallocate(refs,tras,trats)
deallocate(refb,trab,upw)
deallocate(refbs,fabso3c,tra)
deallocate(dow,atln,absn)
deallocate(fnebmax,fneba)

return

!========================
!7. additional functions:
!========================
contains


!> \brief Internal function -
!>  Computes ozone concentration for the altitude zh
!-------------------------------------------------------------------------------
! Arguments
!______________________________________________________________________________.
!  mode           name          role
!______________________________________________________________________________!
!> \param[in]   zh          altitude
!_______________________________________________________________________________

function rayuoz(zh)

  implicit none
  double precision, intent(in) :: zh  ! absolute altitude
  double precision ::  rayuoz
  double precision ::  a, b, c

  a = 0.4d0
  b = 20000.d0
  c = 5000.d0

  rayuoz = a*(1.d0 + exp(-b/c))/(1.d0 + exp((zh-b)/c))

end function rayuoz

! 7.2 Aborption function of the solar radiation by water vapor
!-------------------------------------------------------------------------

!> \brief Internal function -
!>  Aborption function of the solar radiation by water vapor
!-------------------------------------------------------------------------------
! Arguments
!______________________________________________________________________________.
!  mode           name          role
!______________________________________________________________________________!
!> \param[in]       y       optical depth for water vapor
!_______________________________________________________________________________

function raysve(y)

  implicit none
  double precision, intent(in) :: y        ! specific humidity
  double precision :: raysve

  raysve = 0.29d0*y/((1.d0 + 14.15d0*y)**0.635d0 + 0.5925d0*y)

end function raysve

! 7.3 Aborption function of the solar radiation by ozone
!--------------------------------------------------------

!> \brief Internal function -
!>  Aborption function of the solar radiation by ozone
!-------------------------------------------------------------------------------
! Arguments
!______________________________________________________________________________.
!  mode           name          role
!______________________________________________________________________________!
!> \param[in]       x       optical depth for ozone
!_______________________________________________________________________________

function raysoz(x)
  implicit none
  double precision, intent(in) :: x
  double precision :: raysoz
  double precision :: ao3vis, ao3uv

  ao3vis = 0.02118d0*x/(1.d0 + (0.042d0 + 0.000323d0*x)*x)
  ao3uv = 1.082d0*x/(1.d0 + 138.6d0*x)**0.805d0                     &
        + 0.0658d0*x/(1.d0 + (103.6d0*x)**3)
  raysoz = ao3vis + ao3uv

end function raysoz

end subroutine rayso


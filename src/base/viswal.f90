!-------------------------------------------------------------------------------

!     This file is part of the Code_Saturne Kernel, element of the
!     Code_Saturne CFD tool.

!     Copyright (C) 1998-2009 EDF S.A., France

!     contact: saturne-support@edf.fr

!     The Code_Saturne Kernel is free software; you can redistribute it
!     and/or modify it under the terms of the GNU General Public License
!     as published by the Free Software Foundation; either version 2 of
!     the License, or (at your option) any later version.

!     The Code_Saturne Kernel is distributed in the hope that it will be
!     useful, but WITHOUT ANY WARRANTY; without even the implied warranty
!     of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!     GNU General Public License for more details.

!     You should have received a copy of the GNU General Public License
!     along with the Code_Saturne Kernel; if not, write to the
!     Free Software Foundation, Inc.,
!     51 Franklin St, Fifth Floor,
!     Boston, MA  02110-1301  USA

!-------------------------------------------------------------------------------

subroutine viswal &
!================

 ( idbia0 , idbra0 ,                                              &
   nvar   , nscal  , ncepdp , ncesmp ,                            &
   icepdc , icetsm , itypsm ,                                     &
   ia     ,                                                       &
   dt     , rtp    , rtpa   , propce , propfa , propfb ,          &
   coefa  , coefb  , ckupdc , smacel ,                            &
   w1     , w2     , w3     , w4     ,                            &
   w5     , w6     , w7     , w8     ,                            &
   w9     , w10    , w11    , w12    ,                            &
   ra     )

!===============================================================================
! FONCTION :
! --------

! CALCUL DE LA VISCOSITE "TURBULENTE" POUR
!          UN MODELE LES WALE

! PROPCE(1,IVISCT) = ROM * (CWALE*L)**2 *
!   [(Sijd.Sijd)**(3/2)] / [(Sij.Sij)**(5/2) + (Sijd.Sijd)**(5/4)]
!
! avec
!       Sij = 0.5*[DUi/Dxj + DUj/Dxi]
! et
!       Sijd = 0.5*[DUi/Dxk.DUk/Dxj + DUj/Dxk.DUk/Dxi] - 1/3*Delta_ij.Gkk**2

! On dispose des types de faces de bord au pas de temps
!   precedent (sauf au premier pas de temps, ou les tableaux
!   ITYPFB et ITRIFB n'ont pas ete renseignes)

! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! idbia0           ! i  ! <-- ! number of first free position in ia            !
! idbra0           ! i  ! <-- ! number of first free position in ra            !
! nvar             ! i  ! <-- ! total number of variables                      !
! nscal            ! i  ! <-- ! total number of scalars                        !
! ncepdp           ! i  ! <-- ! number of cells with head loss                 !
! ncesmp           ! i  ! <-- ! number of cells with mass source term          !
! icepdc(ncelet    ! te ! <-- ! numero des ncepdp cellules avec pdc            !
! icetsm(ncesmp    ! te ! <-- ! numero des cellules a source de masse          !
! itypsm           ! te ! <-- ! type de source de masse pour les               !
! (ncesmp,nvar)    !    !     !  variables (cf. ustsma)                        !
! ia(*)            ! ia ! --- ! main integer work array                        !
! dt(ncelet)       ! ra ! <-- ! time step (per cell)                           !
! rtp, rtpa        ! ra ! <-- ! calculated variables at cell centers           !
!  (ncelet, *)     !    !     !  (at current and previous time steps)          !
! propce(ncelet, *)! ra ! <-- ! physical properties at cell centers            !
! propfa(nfac, *)  ! ra ! <-- ! physical properties at interior face centers   !
! propfb(nfabor, *)! ra ! <-- ! physical properties at boundary face centers   !
! coefa, coefb     ! ra ! <-- ! boundary conditions                            !
!  (nfabor, *)     !    !     !                                                !
! ckupdc(ncepdp    ! tr ! <-- ! tableau de travail pour pdc                    !
!     , 6)!        !     !                                                !
! smacel           ! tr ! <-- ! valeur des variables associee a la             !
! (ncesmp,*   )    !    !     !  source de masse                               !
!                  !    !     !  pour ivar=ipr, smacel=flux de masse           !
! w1..12(ncelet    ! tr ! --- ! tableau de travail                             !
! ra(*)            ! ra ! --- ! main real work array                           !
!__________________!____!_____!________________________________________________!

!     TYPE : E (ENTIER), R (REEL), A (ALPHANUMERIQUE), T (TABLEAU)
!            L (LOGIQUE)   .. ET TYPES COMPOSES (EX : TR TABLEAU REEL)
!     MODE : <-- donnee, --> resultat, <-> Donnee modifiee
!            --- tableau de travail
!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use dimens, only: ndimfb
use numvar
use optcal
use cstphy
use entsor
use parall
use mesh

!===============================================================================

implicit none

! Arguments

integer          idbia0 , idbra0
integer          nvar   , nscal
integer          ncepdp , ncesmp

integer          icepdc(ncepdp)
integer          icetsm(ncesmp), itypsm(ncesmp,nvar)
integer          ia(*)

double precision dt(ncelet), rtp(ncelet,*), rtpa(ncelet,*)
double precision propce(ncelet,*)
double precision propfa(nfac,*), propfb(ndimfb,*)
double precision coefa(ndimfb,*), coefb(ndimfb,*)
double precision ckupdc(ncepdp,6), smacel(ncesmp,nvar)
double precision w1(ncelet)   , w2(ncelet)   , w3(ncelet)
double precision w4(ncelet)   , w5(ncelet)   , w6(ncelet)
double precision w7(ncelet)   , w8(ncelet)   , w9(ncelet)
double precision w10(ncelet)  , w11(ncelet)  , w12(ncelet)
double precision ra(*)

! Local variables

integer          idebia, idebra, ifinra
integer          iel, iccocg, inc
integer          iuiph, iviph, iwiph
integer          ipcliu, ipcliv, ipcliw
integer          ipcrom, ipcvst, iphydp, ipcvis
integer          i, j, k

double precision coef, deux, delta, tiers
double precision sij, sijd, s, sd, sinv
double precision xfil, xa  , xb  , radeux, con
double precision dudx(ndim,ndim), kdelta(ndim,ndim)

!===============================================================================

!===============================================================================
! 1.  INITIALISATION
!===============================================================================

! --- Memoire
idebia = idbia0
idebra = idbra0


! --- Numero des variables (dans RTP)
iuiph = iu
iviph = iv
iwiph = iw

! --- Rang des variables dans PROPCE (prop. physiques au centre)
ipcvis = ipproc(iviscl)
ipcvst = ipproc(ivisct)
ipcrom = ipproc(irom  )

! --- Rang des c.l. des variables dans COEFA COEFB
!        (c.l. std, i.e. non flux)
ipcliu = iclrtp(iuiph,icoef)
ipcliv = iclrtp(iviph,icoef)
ipcliw = iclrtp(iwiph,icoef)
! --- Pour le calcul de la viscosite de sous-maille
xfil   = xlesfl
xa     = ales
xb     = bles
deux   = 2.d0
radeux = sqrt(deux)
tiers  = 1.d0/3.d0


!===============================================================================
! 2.  CALCUL DU GRADIENT DE VITESSE
!       W1 = DU/DX, W2 = DU/DY, W3 = DU/DZ
!       W4 = DV/DX, W5 = DV/DY, W6 = DV/DZ
!       W7 = DW/DX, W8 = DW/DY, W9 = DW/DZ
!===============================================================================

iccocg = 1
inc = 1
iphydp = 0

call grdcel                                                       &
!==========
 ( idebia , idebra ,                                              &
   iuiph  , imrgra , inc    , iccocg ,                            &
   nswrgr(iuiph) , imligr(iuiph) , iphydp , iwarni(iuiph) ,       &
   nfecra , epsrgr(iuiph) , climgr(iuiph) , extrag(iuiph) ,       &
   ia     ,                                                       &
   w12    , w12    , w12    ,                                     &
   rtpa(1,iuiph) , coefa(1,ipcliu) , coefb(1,ipcliu) ,            &
   w1            , w2              , w3              ,            &
!        ------   ------   ------
   w10           , w11             , w12             ,            &
   ra     )

call grdcel                                                       &
!==========
 ( idebia , idebra ,                                              &
   iviph  , imrgra , inc    , iccocg ,                            &
   nswrgr(iviph) , imligr(iviph) , iphydp , iwarni(iviph) ,       &
   nfecra , epsrgr(iviph) , climgr(iviph) , extrag(iviph) ,       &
   ia     ,                                                       &
   w12    , w12    , w12    ,                                     &
   rtpa(1,iviph) , coefa(1,ipcliv) , coefb(1,ipcliv) ,            &
   w4            , w5              , w6              ,            &
!        ------   ------   ------
   w10           , w11             , w12             ,            &
   ra     )

call grdcel                                                       &
!==========
 ( idebia , idebra ,                                              &
   iwiph  , imrgra , inc    , iccocg ,                            &
   nswrgr(iwiph) , imligr(iwiph) , iphydp , iwarni(iwiph) ,       &
   nfecra , epsrgr(iwiph) , climgr(iwiph) , extrag(iwiph) ,       &
   ia     ,                                                       &
   w12    , w12    , w12    ,                                     &
   rtpa(1,iwiph) , coefa(1,ipcliw) , coefb(1,ipcliw) ,            &
   w7            , w8              , w9            ,              &
!        ------   ------   ------
   w10           , w11             , w12             ,            &
   ra     )

! Kronecker delta Dij

kdelta(1,1) = 1
kdelta(1,2) = 0
kdelta(1,3) = 0
kdelta(2,1) = 0
kdelta(2,2) = 1
kdelta(2,3) = 0
kdelta(3,1) = 0
kdelta(3,2) = 0
kdelta(3,3) = 1

coef = cwale**2 * radeux

do iel = 1, ncel

  dudx(1,1) = w1(iel)
  dudx(1,2) = w2(iel)
  dudx(1,3) = w3(iel)
  dudx(2,1) = w4(iel)
  dudx(2,2) = w5(iel)
  dudx(2,3) = w6(iel)
  dudx(3,1) = w7(iel)
  dudx(3,2) = w8(iel)
  dudx(3,3) = w9(iel)

  s  = 0.d0
  sd = 0.d0

  do i = 1, ndim
    do j = 1, ndim

      ! Sij = 0.5 * (dUi/dXj + dUj/dXi)

      sij = 0.5d0*(dudx(i,j)+dudx(j,i))

      s = s + sij**2

      do k = 1, ndim

!  traceless symmetric part of the square of the velocity gradient tensor
!    Sijd = 0.5 * ( dUi/dXk dUk/dXj + dUj/dXk dUk/dXi) - 1/3 Dij dUk/dXk dUk/dXk

        sijd = 0.5d0*(dudx(i,k)*dudx(k,j)+ dudx(j,k)*dudx(k,i)) &
              -tiers*kdelta(i,j)*dudx(k,k)**2

        sd = sd + sijd**2

      enddo
    enddo
  enddo

!===============================================================================
! 3.  CALCUL DE LA VISCOSITE TURBULENTE
!===============================================================================

  ! Turbulent inverse time scale =
  !   (Sijd Sijd)^3/2 / [ (Sij Sij)^5/2 + (Sijd Sijd)^5/4 ]

  sinv = (s**2.5d0 + sd**1.25d0)
  if (sinv.gt.0.d0) then
    con = sd**1.5d0 / sinv
  else
    con = 0.d0
  endif

  delta = xfil* (xa*volume(iel))**xb
  delta = coef * delta**2

  propce(iel,ipcvst) = propce(iel,ipcrom) * delta * con

enddo

!----
! FORMAT
!----

!----
! FIN
!----

return

end subroutine

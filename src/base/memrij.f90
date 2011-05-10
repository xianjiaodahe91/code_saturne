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

subroutine memrij &
!================

 ( idbia0 , idbra0 ,                                              &
   nvar   , nscal  ,                                                                                 &
   iturbp ,                                                       &
   idtr   , iviscf , iviscb , icoefx ,                            &
   idam   , ixam   , idrtp  ,                                     &
   ismbr  , irovsd , igrdvt , iprodu , igrarx , igrary , igrarz , &
   iw1    , iw2    , iw3    , iw4    , iw5    , iw6    , iw7    , &
   iw8    , iw9    ,                                              &
   ifinia , ifinra )

!===============================================================================
!  FONCTION
!  --------

!  GESTION MEMOIRE RIJ-EPSILON

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! idbia0           ! i  ! <-- ! number of first free position in ia            !
! idbra0           ! i  ! <-- ! number of first free position in ra            !
! nvar             ! i  ! <-- ! total number of variables                      !
! nscal            ! i  ! <-- ! total number of scalars                        !
! idtr             ! e  ! --> ! "pointeur" sur dtr                             !
! iviscf, b        ! e  ! --> ! "pointeur" sur viscf, viscb                    !
! icoefx           ! e  ! --> ! "pointeur" sur coefax                          !
!                  ! tr ! --- !   attention : uniquement avec echo             !
!                  ! tr ! --- !   de paroi et abs(icdpar) = 1                  !
! idam, ixam       ! e  ! --> ! "pointeur" sur dam, xam                        !
! idrtp            ! e  ! --> ! "pointeur" sur drtp                            !
! ismbr            ! e  ! --> ! "pointeur" sur smbr                            !
! irovsd           ! e  ! --> ! "pointeur" sur rovsdt                          !
! igrdvt           ! e  ! --> ! "pointeur" sur grdvit                          !
! iprodu           ! e  ! --> ! "pointeur" sur produc                          !
! igrarx,y,z       ! e  ! --> ! "pointeur" sur grarox, y, z                    !
! iw1,2,...,9      ! e  ! --> ! "pointeur" sur w1 a w9                         !
! ifinia           ! i  ! --> ! number of first free position in ia (at exit)  !
! ifinra           ! i  ! --> ! number of first free position in ra (at exit)  !
!__________________.____._____.________________________________________________.

!     TYPE : E (ENTIER), R (REEL), A (ALPHANUMERIQUE), T (TABLEAU)
!            L (LOGIQUE)   .. ET TYPES COMPOSES (EX : TR TABLEAU REEL)
!     MODE : <-- donnee, --> resultat, <-> Donnee modifiee
!            --- tableau de travail
!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use optcal
use mesh

!===============================================================================

implicit none

! Arguments

integer          idbia0 , idbra0
integer          nvar   , nscal
integer          iturbp

integer          idtr
integer          iviscf , iviscb , icoefx
integer          idam   , ixam
integer          idrtp  , ismbr  , irovsd , igrdvt , iprodu
integer          igrarx , igrary , igrarz
integer          iw1    , iw2    , iw3    , iw4    , iw5    , iw6
integer          iw7    , iw8    , iw9
integer          ifinia , ifinra

integer          idebia, idebra, jgrari, icobx

!===============================================================================

!---> INITIALISATION

idebia = idbia0
idebra = idbra0

jgrari = 0
if(igrari.eq.1) then
  jgrari = 1
endif


icobx = 0
if(abs(icdpar).eq.1) then
  if(irijec.eq.1) then
    icobx = 1
  endif
endif


!---> PLACE MEMOIRE RESERVEE AVEC DEFINITION DE IFINIA IFINRA

idtr   =       idebra
iviscf =       idtr   + ncelet
iviscb =       iviscf + nfac
icoefx =       iviscb + nfabor
idam   =       icoefx + nfabor*icobx
ixam   =       idam   + ncelet
idrtp  =       ixam   + nfac*2
ismbr  =       idrtp  + ncelet
irovsd =       ismbr  + ncelet
!     suivant qu'on est en ITURB=30 ou 31 on
!     reserve PRODUC ou GRDVIT
igrdvt =       irovsd + ncelet
iprodu =       igrdvt
if (iturbp.eq.30) then
  igrarx =       iprodu + ncelet*6
else
  igrarx =       igrdvt + ncelet*9
endif
igrary =       igrarx + ncelet*jgrari
igrarz =       igrary + ncelet*jgrari
iw1    =       igrarz + ncelet*jgrari
iw2    =       iw1    + ncelet
iw3    =       iw2    + ncelet
iw4    =       iw3    + ncelet
iw5    =       iw4    + ncelet
iw6    =       iw5    + ncelet
iw7    =       iw6    + ncelet
iw8    =       iw7    + ncelet
iw9    =       iw8    + ncelet
ifinra =       iw9    + ncelet

!---> VERIFICATION

call rasize('memrij',ifinra)
!==========

return
end subroutine

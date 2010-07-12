#ifndef _ECS_CHAMP_COMM_H_
#define _ECS_CHAMP_COMM_H_

/*============================================================================
 *  Prototypes des fonctions
 *   associées à la structure `ecs_champ_t' décrivant un champ
 *   et réalisant des communications
 *============================================================================*/

/*
  This file is part of the Code_Saturne Preprocessor, element of the
  Code_Saturne CFD tool.

  Copyright (C) 1999-2009 EDF S.A., France

  contact: saturne-support@edf.fr

  The Code_Saturne Preprocessor is free software; you can redistribute it
  and/or modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation; either version 2 of
  the License, or (at your option) any later version.

  The Code_Saturne Preprocessor is distributed in the hope that it will be
  useful, but WITHOUT ANY WARRANTY; without even the implied warranty
  of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with the Code_Saturne Preprocessor; if not, write to the
  Free Software Foundation, Inc.,
  51 Franklin St, Fifth Floor,
  Boston, MA  02110-1301  USA
*/


/*============================================================================
 *                                 Visibilité
 *============================================================================*/

/*----------------------------------------------------------------------------
 *  Fichiers `include' librairie standard C
 *----------------------------------------------------------------------------*/


/*----------------------------------------------------------------------------
 *  Fichiers `include' publics  du  paquetage global "Utilitaire"
 *----------------------------------------------------------------------------*/


/*----------------------------------------------------------------------------
 *  Fichiers `include' publics  du  paquetage global "Post-Traitement"
 *----------------------------------------------------------------------------*/


/*----------------------------------------------------------------------------
 *  Fichiers `include' publics  des paquetages visibles
 *----------------------------------------------------------------------------*/

#include "ecs_comm.h"


/*----------------------------------------------------------------------------
 *  Fichiers `include' publics  du  paquetage courant
 *----------------------------------------------------------------------------*/

#include "ecs_champ.h"


/*============================================================================
 *                       Prototypes de fonctions publiques
 *============================================================================*/

/*----------------------------------------------------------------------------
 *  Fonction qui ecrit le tableau des positions d'un champ
 *   dans le fichier d'interface pour le Noyau
 *----------------------------------------------------------------------------*/

void
ecs_champ_comm__ecr_pos(ecs_champ_t  *this_champ,
                        const char   *comm_nom_rubrique,
                        size_t        location_id,
                        size_t        index_id,
                        ecs_comm_t   *comm);

/*----------------------------------------------------------------------------
 *  Fonction qui écrit le contenu d'un champ
 *   dans le fichier d'interface pour le Noyau
 *----------------------------------------------------------------------------*/

void ecs_champ_comm__ecr(ecs_champ_t  *this_champ,
                         const char   *comm_nom_rubrique,
                         size_t        location_id,
                         size_t        index_id,
                         size_t        n_location_values,
                         ecs_comm_t   *comm);

/*----------------------------------------------------------------------------*/

#endif /* _ECS_CHAMP_COMM_H_ */

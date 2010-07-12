#ifndef _ECS_CHAMP_POST_CGNS_H_
#define _ECS_CHAMP_POST_CGNS_H_

/*============================================================================
 * Functions associated with a `ecs_champ_t' structure describing a field
 * for CGNS output.
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

#include "cs_config.h"

#if defined(HAVE_CGNS)

/*----------------------------------------------------------------------------
 * Standard C library headers
 *----------------------------------------------------------------------------*/

/*----------------------------------------------------------------------------
 * Local headers
 *----------------------------------------------------------------------------*/

#include "ecs_tab_glob.h"
#include "ecs_champ.h"

#include "ecs_post.h"

#include "ecs_post_cgns.h"
#include "ecs_post_cgns_priv.h"

/*============================================================================
 * Public function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Write element connectivity based on geometric type.
 *
 * Elements must have been previously sorted by type, and polyhedra
 * are ignored.
 *---------------------------------------------------------------------------*/

void
ecs_champ_post_cgns__ecr_connect(const char            *nom_maillage,
                                 size_t                 n_vertices,
                                 const ecs_coord_t      vertex_coords[],
                                 ecs_champ_t           *champ_def,
                                 const int              elt_fam[],
                                 const ecs_tab_int_t   *tab_elt_typ_geo,
                                 ecs_post_cgns_t       *cas_cgns);

/*----------------------------------------------------------------------------
 * Write per-element values for a given array.
 *
 * Values corresponding to polyhedra are ignored.
 *---------------------------------------------------------------------------*/

void
ecs_champ_post_cgns__ecr_val(const ecs_tab_int_t  *tab_val,
                             const char           *nom_maillage,
                             const char           *nom_champ,
                             ecs_post_cgns_t      *cas_cgns);


#endif /* HAVE_CGNS */

/*----------------------------------------------------------------------------*/

#endif /* _ECS_CHAMP_POST_CGNS_H_ */

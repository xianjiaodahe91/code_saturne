# -*- coding: utf-8 -*-

#-------------------------------------------------------------------------------

# This file is part of Code_Saturne, a general-purpose CFD tool.
#
# Copyright (C) 1998-2013 EDF S.A.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
# Street, Fifth Floor, Boston, MA 02110-1301, USA.

#-------------------------------------------------------------------------------

"""
This page is devoted to the time step management.

This module contains the following classes and function:
- TimeStepModel
- TimeStepModelTestCase
"""

#-------------------------------------------------------------------------------
# Library modules import
#-------------------------------------------------------------------------------

import unittest

#-------------------------------------------------------------------------------
# Application modules import
#-------------------------------------------------------------------------------

from Base.Common import *
import Base.Toolbox as Tool
from Base.XMLvariables import Variables, Model
from Base.XMLmodel import ModelTest
from Pages.OutputVolumicVariablesModel import OutputVolumicVariablesModel

#-------------------------------------------------------------------------------
# Time Step Model class
#-------------------------------------------------------------------------------

class TimeStepModel(Model):
    """
    Class to open the Time Step Page.
    """
    def __init__(self, case):
        """
        Constructor.
        """
        self.case =case

        self.node_models       = self.case.xmlGetNode('thermophysical_models')
        self.node_turb         = self.node_models.xmlGetNode('turbulence')
        self.node_control      = self.case.xmlGetNode('analysis_control')
        self.node_time         = self.node_control.xmlInitNode('time_parameters')


    def defaultValues(self):
        """
        Return in a dictionnary which contains default values
        """
        default = {}

        default['iterations']        = 10
        default['time_passing']      = 0
        default['time_step_ref']     = 0.1
        default['max_courant_num']   = 1.0
        default['max_fourier_num']   = 10.0
        default['time_step_min_factor'] = 0.1
        default['time_step_max_factor'] = 1000.0
        default['time_step_var']     = 0.1
        default['thermal_time_step'] = 'off'
        default['zero_time_step']    = 'off'

        return default


    def thermalCase(self):
        """
        Is the current case adapted for IPTLRO ?
        """
        thermal_case = 0
        from Pages.FluidCharacteristicsModel import FluidCharacteristicsModel
        n_atmo, n_joul, n_thermo, n_gas, n_coal, n_comp = FluidCharacteristicsModel(self.case).getThermoPhysicalModel()

        if n_atmo != 'off' or n_joul != 'off' or  n_thermo != 'off' or  n_gas != 'off' or  n_coal != 'off':
           thermal_case = 1

        # gravity
        from Pages.BodyForcesModel import BodyForcesModel
        mdl = BodyForcesModel(self.case)
        gx = mdl.getGravity('gravity_x')
        gy = mdl.getGravity('gravity_y')
        gz = mdl.getGravity('gravity_z')
        if gx == 0.0 and gy  == 0.0 and gz == 0.0:
            thermal_case = 0

        # rho variable
        if FluidCharacteristicsModel(self.case).getPropertyMode('density') == 'constant':
            thermal_case = 0

        del FluidCharacteristicsModel
        del BodyForcesModel
        return thermal_case


    @Variables.noUndo
    def getTimePassing(self):
        """
        Get value of time_passing (IDTVAR) for node "time_parameters"
        """
        tag = 'time_passing'
        v = self.node_time.xmlGetInt(tag)
        if v == None:
            v = self.defaultValues()[tag]
            self.setTimePassing(v)

        from Pages.TurbulenceModel import TurbulenceModel
        model = TurbulenceModel(self.case).getTurbulenceModel()
        del TurbulenceModel
        if model in ('LES_Smagorinsky', 'LES_dynamique', 'LES_WALE'):
            v = 0
            self.setTimePassing(v)

        return v


    @Variables.undoGlobal
    def setTimePassing(self, val):
        """
        Get value of time_passing (IDTVAR) for node "time_parameters"
        Used also by TurbulenceModel
        """
        self.isIntInList(val, [0, 1, 2])
        self.node_time.xmlSetData('time_passing', val)

        Variables(self.case).setNewProperty(self.node_time, 'courant_number')
        Variables(self.case).setNewProperty(self.node_time, 'fourier_number')

        if val in (1, 2):
            Variables(self.case).setNewProperty(self.node_time, 'local_time_step')
            n = self.node_time.xmlInitNode('property', name='local_time_step')
            if val == 1:
                n.xmlInitNode('postprocessing_recording')['status']= "off"
                n.xmlInitNode('probes')['choice']= "0"
            else:
                n.xmlRemoveChild('postprocessing_recording')
                n.xmlRemoveChild('probes')
        else:
            self.node_time.xmlRemoveChild('property', name='local_time_step')
            for tag in ('max_courant_num',
                        'max_fourier_num',
                        'time_step_min_factor',
                        'time_step_max_factor',
                        'time_step_var'):
                self.node_time.xmlRemoveChild(tag)


    @Variables.noUndo
    def getTimeStep(self):
        """
        Get value of time_step_reference for node "time_parameters"
        """
        tag = 'time_step_ref'
        v = self.node_time.xmlGetDouble(tag)
        if v == None:
            v = self.defaultValues()[tag]
            self.setTimeStep(v)

        return v


    @Variables.undoLocal
    def setTimeStep(self, val):
        """
        Get value of time_step_reference for node "time_parameters"
        """
        self.isPositiveFloat(val)
        self.node_time.xmlSetData('time_step_ref', val)


    @Variables.noUndo
    def getIterationsNumber(self):
        """
        Get number of iterations for node "time_parameters"
        """
        tag = 'iterations'
        v = self.node_time.xmlGetInt(tag)
        if v == None:
            v = self.defaultValues()[tag]
            self.setIterationsNumber(v)
        return v


    @Variables.undoLocal
    def setIterationsNumber(self, val):
        """
        Put number of iterations for node "time_parameters"
        """
        self.isPositiveInt(val)
        self.node_time.xmlSetData('iterations', val)


    @Variables.noUndo
    def getMaxCourant(self):
        """
        Return the max courant number allowed
        """
        tag = 'max_courant_num'
        return self.getOptions(tag)


    @Variables.undoGlobal
    def setMaxCourant(self, val):
        """
        Input the max courant number allowed
        """
        self.isStrictPositiveFloat(val)
        self.setOptions('max_courant_num', val)


    @Variables.noUndo
    def getMaxFourier(self):
        """
        Return the max fourier number allowed
        """
        tag = 'max_fourier_num'
        return self.getOptions(tag)


    @Variables.undoGlobal
    def setMaxFourier(self, val):
        """
        Input the max fourier number allowed
        """
        self.isStrictPositiveFloat(val)
        self.setOptions('max_fourier_num', val)


    @Variables.noUndo
    def getTimeStepMinFactor(self):
        """
        Return the minimal time step factor
        """
        tag = 'time_step_min_factor'
        return self.getOptions(tag)


    @Variables.undoGlobal
    def setTimeStepMinFactor(self, val):
        """
        Input the minimal time step factor
        """
        self.isPositiveFloat(val)
        self.setOptions('time_step_min_factor', val)


    @Variables.noUndo
    def getTimeStepMaxFactor(self):
        """
        Return the maximal time step factor
        """
        tag = 'time_step_max_factor'
        return self.getOptions(tag)


    @Variables.undoGlobal
    def setTimeStepMaxFactor(self, val):
        """
        Input the maximal time step factor
        """
        self.isStrictPositiveFloat(val)
        self.setOptions('time_step_max_factor', val)


    @Variables.noUndo
    def getTimeStepVariation(self):
        """
        Return the maximal variation of time step between two iteration
        """
        tag = 'time_step_var'
        return self.getOptions(tag)


    @Variables.undoGlobal
    def setTimeStepVariation(self, val):
        """
        Input the maximal variation of time step between two iteration
        """
        self.isStrictPositiveFloat(val)
        self.setOptions('time_step_var', val)


    @Variables.noUndo
    def getOptions(self, tag):
        """
        Get options for node "time_parameters"
        """
        if self.getTimePassing() == 0:
            msg = "No option : " + tag + " in this case"
            raise ValueError(msg)

        v = self.node_time.xmlGetChildDouble(tag)
        if v == None:
            v = self.defaultValues()[tag]
            self.setOptions(tag, v)
        return v


    @Variables.undoLocal
    def setOptions(self, tag, val):
        """
        Put options for node "time_parameters"
        """
        if self.getTimePassing() == 0:
            msg = "No option : " + tag + " in this case"
            raise ValueError(msg)

        if tag == 'time_step_min_factor':
            self.isPositiveFloat(val)
        else:
            self.isStrictPositiveFloat(val)
        self.node_time.xmlSetData(tag, val)


    @Variables.noUndo
    def getThermalTimeStep(self):
        """
        Get status of thermal_time_step for node "time_parameters"
        """
        if not self.thermalCase():
            raise ValueError("TimeStepModel: no thermal model in this case")

        node = self.node_time.xmlInitChildNode('thermal_time_step', 'status')
        s = node['status']
        if not s:
            s = self.defaultValues()['thermal_time_step']
            self.setThermalTimeStep(s)
        return s


    @Variables.undoLocal
    def setThermalTimeStep(self, status):
        """
        Put status of thermal_time_step for node "time_parameters"
        """

        if not self.thermalCase():
            raise ValueError("TimeStepModel: no thermal model in this case")

        self.isOnOff(status)
        node = self.node_time.xmlInitChildNode('thermal_time_step', 'status')
        node['status'] = status


    @Variables.noUndo
    def getZeroTimeStep(self):
        """
        Get status of zero_time_step for node "time_parameters"
        """
        node = self.node_time.xmlInitNode('zero_time_step', 'status')
        s = node['status']
        if not s:
            s = self.defaultValues()['zero_time_step']
            self.setZeroTimeStep(s)
        return s


    @Variables.undoLocal
    def setZeroTimeStep(self, status):
        """
        Get status of zero_time_step for node "time_parameters"
        """
        self.isOnOff(status)
        node = self.node_time.xmlInitChildNode('zero_time_step', 'status')
        node['status'] = status


    def RemoveThermalTimeStepNode(self):
        """
        Remove Thermal time step node for node "time_parameters"
        Also called by ThermalScalarModel
        """
        node = self.node_time.xmlGetNode('thermal_time_step')
        if node:
            self.node_time.xmlRemoveChild('thermal_time_step')

#-------------------------------------------------------------------------------
# TimeStepModel Test Class
#-------------------------------------------------------------------------------

class TimeStepModelTestCase(ModelTest):
    """
    """
    def checkTimeStepModelInstantiation(self):
        """Check whether the TimeStepModel class could be instantiated"""
        mdl = None
        mdl = TimeStepModel(self.case)
        assert mdl != None, 'Could not instantiate TimeStepModel'

    def checkSetandGetTimePassing(self):
        """Check whether the TimeStepModel class could be set and get time passing"""
        mdl = TimeStepModel(self.case)
        mdl.setTimePassing(1)
        doc = '''<time_parameters>
                    <property label="Courant nb" name="courant_number"/>
                    <property label="Fourier nb" name="fourier_number"/>
                    <time_step_ref>0.1</time_step_ref>
                    <iterations>10</iterations>
                    <time_passing>1</time_passing>
                    <property label="loc.time" name="local_time_step"/>
                 </time_parameters>'''
        assert mdl.node_time == self.xmlNodeFromString(doc),\
            'Could not set time passing in TimeStepModel'
        assert mdl.getTimePassing() == 1,\
            'Could not get time passing in TimeStepModel'

        mdl.setTimePassing(0)
        doc = '''<time_parameters>
                    <property label="Courant nb" name="courant_number"/>
                    <property label="Fourier nb" name="fourier_number"/>
                    <time_step_ref>0.1</time_step_ref>
                    <iterations>10</iterations>
                    <time_passing>0</time_passing>
                 </time_parameters>'''
        assert mdl.node_time == self.xmlNodeFromString(doc),\
            'Could not remove local time step node in TimeStepModel'

        mdl.setTimePassing(2)
        mdl.setTimeStepMin(0.05)
        mdl.setTimeStepMax(500)
        mdl.setTimeStepVariation(0.25)
        mdl.setTimePassing(0)
        doc = '''<time_parameters>
                    <property label="Courant nb" name="courant_number"/>
                    <property label="Fourier nb" name="fourier_number"/>
                    <time_step_ref>0.1</time_step_ref>
                    <iterations>10</iterations>
                    <time_passing>0</time_passing>
                 </time_parameters>'''
        assert mdl.node_time == self.xmlNodeFromString(doc),\
            'Could not remove tagged time node in TimeStepModel'

    def checkSetandGetIterationsNumber(self):
        """Check whether the TimeStepModel class could be set and get number of iterations"""
        mdl = TimeStepModel(self.case)
        mdl.setIterationsNumber(50)
        doc = '''<time_parameters>
                    <property label="Courant nb" name="courant_number"/>
                    <property label="Fourier nb" name="fourier_number"/>
                    <time_step_ref>0.1</time_step_ref>
                    <iterations>50</iterations>
                    <time_passing>0</time_passing>
                 </time_parameters>'''
        assert mdl.node_time == self.xmlNodeFromString(doc),\
            'Could not set number of iterations in TimeStepModel'
        assert mdl.getIterationsNumber() == 50,\
            'Could not get number of iterations in TimeStepModel'

    def checkSetandGetMaxCourant(self):
        """Check whether the TimeStepModel class could be
        set and get max courant number : option(s) only for idtvar = 1 or 2"""
        mdl = TimeStepModel(self.case)
        mdl.setTimePassing(1)
        mdl.setMaxCourant(10)
        doc = '''<time_parameters>
                    <property label="Courant nb" name="courant_number"/>
                    <property label="Fourier nb" name="fourier_number"/>
                    <time_step_ref>0.1</time_step_ref>
                    <iterations>10</iterations>
                    <time_passing>1</time_passing>
                    <property label="loc.time" name="local_time_step"/>
                    <max_courant_num>10</max_courant_num>
                 </time_parameters>'''
        assert mdl.node_time == self.xmlNodeFromString(doc),\
            'Could not set max courant number in TimeStepModel'
        assert mdl.getMaxCourant() == 10,\
            'Could not get max courant number in TimeStepModel'

    def checkSetandGetMaxFourier(self):
        """Check whether the TimeStepModel class could be set and get
         max fourier number (if idtvar = 0 : no options max fourier)"""
        mdl = TimeStepModel(self.case)
        mdl.setTimePassing(1)
        mdl.setMaxFourier(100.)
        doc = '''<time_parameters>
                    <property label="Courant nb" name="courant_number"/>
                    <property label="Fourier nb" name="fourier_number"/>
                    <time_step_ref>0.1</time_step_ref>
                    <iterations>10</iterations>
                    <time_passing>1</time_passing>
                    <property label="loc.time" name="local_time_step"/>
                    <max_fourier_num>100.</max_fourier_num>
                 </time_parameters>'''
        assert mdl.node_time == self.xmlNodeFromString(doc),\
            'Could not set max fourier number in TimeStepModel'
        assert mdl.getMaxFourier() == 100.,\
            'Could not get max fourier number in TimeStepModel'

    def checkSetandGetTimeStepMinMaxandVariation(self):
        """Check whether the TimeStepModel class could be set and get
         options :min max and variation for time step"""
        mdl = TimeStepModel(self.case)
        mdl.setTimePassing(2)
        mdl.setTimeStepMin(0.05)
        mdl.setTimeStepMax(500)
        mdl.setTimeStepVariation(0.25)
        doc = '''<time_parameters>
                    <property label="Courant nb" name="courant_number"/>
                    <property label="Fourier nb" name="fourier_number"/>
                    <time_step_ref>0.1</time_step_ref>
                    <iterations>10</iterations>
                    <time_passing>2</time_passing>
                    <property label="loc.time" name="local_time_step"/>
                    <time_step_min_factor>0.05</time_step_min_factor>
                    <time_step_max_factor>500</time_step_max_factor>
                    <time_step_var>0.25</time_step_var>
                 </time_parameters>'''
        assert mdl.node_time == self.xmlNodeFromString(doc),\
            'Could not set min max and variation of time step in TimeStepModel'
        assert mdl.getTimeStepMin() == 0.05,\
            'Could not get min of time step in TimeStepModel'
        assert mdl.getTimeStepMax() == 500,\
            'Could not get max of time step in TimeStepModel'
        assert mdl.getTimeStepVariation() == 0.25,\
            'Could not get variation of time step in TimeStepModel'

    def checkSetandGetThermalTimeStep(self):
        """Check whether the TimeStepModel class could be set and get thermal time step"""
        mdl = TimeStepModel(self.case)
        from Pages.ThermalScalarModel import ThermalScalarModel
        ThermalScalarModel(self.case).setThermalModel('temperature_celsius')
        del ThermalScalarModel
        from Pages.FluidCharacteristicsModel import FluidCharacteristicsModel
        FluidCharacteristicsModel(self.case).setPropertyMode('density','variable')
        del FluidCharacteristicsModel
        from Pages.BodyForcesModel import BodyForcesModel
        BodyForcesModel(self.case).setGravity('gravity_x', 9.81)
        del BodyForcesModel
        mdl.setThermalTimeStep('on')
        doc = '''<time_parameters>
                    <property label="Courant nb" name="courant_number"/>
                    <property label="Fourier nb" name="fourier_number"/>
                    <time_step_ref>0.1</time_step_ref>
                    <iterations>10</iterations>
                    <time_passing>0</time_passing>
                    <thermal_time_step status="on"/>
                 </time_parameters>'''
        assert mdl.node_time == self.xmlNodeFromString(doc),\
            'Could not set thermal time step in TimeStepModel'
        assert mdl.getThermalTimeStep() == 'on',\
            'Could not get thermal time step in TimeStepModel'

    def checkSetandGetZeroTimeStep(self):
        """Check whether the TimeStepModel class could be set and get zero time step"""
        mdl = TimeStepModel(self.case)
        mdl.setZeroTimeStep('on')
        doc = '''<time_parameters>
                    <property label="Courant nb" name="courant_number"/>
                    <property label="Fourier nb" name="fourier_number"/>
                    <time_step_ref>0.1</time_step_ref>
                    <iterations>10</iterations>
                    <time_passing>0</time_passing>
                    <zero_time_step status="on"/>
                 </time_parameters>'''
        assert mdl.node_time == self.xmlNodeFromString(doc),\
            'Could not set zero time step in TimeStepModel'
        assert mdl.getZeroTimeStep() == 'on',\
            'Could not get zero time step in TimeStepModel'

    def checkRemoveThermalTimeStepNode(self):
        """Check whether the TimeStepModel class could be removed thermal time step node"""
        mdl = TimeStepModel(self.case)
        from Pages.ThermalScalarModel import ThermalScalarModel
        ThermalScalarModel(self.case).setThermalModel('temperature_celsius')
        del ThermalScalarModel
        from Pages.FluidCharacteristicsModel import FluidCharacteristicsModel
        FluidCharacteristicsModel(self.case).setPropertyMode('density','variable')
        del FluidCharacteristicsModel
        from Pages.BodyForcesModel import BodyForcesModel
        BodyForcesModel(self.case).setGravity('gravity_x', 9.81)
        del BodyForcesModel
        mdl.setThermalTimeStep('on')
        mdl.RemoveThermalTimeStepNode()
        doc = '''<time_parameters>
                    <property label="Courant nb" name="courant_number"/>
                    <property label="Fourier nb" name="fourier_number"/>
                    <time_step_ref>0.1</time_step_ref>
                    <iterations>10</iterations>
                    <time_passing>0</time_passing>
                 </time_parameters>'''
        assert mdl.node_time == self.xmlNodeFromString(doc),\
            'Could not remove thermal time step node in TimeStepModel'

def suite():
    testSuite = unittest.makeSuite(TimeStepModelTestCase, "check")
    return testSuite

def runTest():
    print("TimeStepModelTestCase")
    runner = unittest.TextTestRunner()
    runner.run(suite())

#-------------------------------------------------------------------------------
# End
#-------------------------------------------------------------------------------

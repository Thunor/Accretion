//
//  Enviro.swift
//  Accretion
//
//  Ported from ENVIRO.C (Fogg's planetary environment equations).
//

import Foundation

extension StarSystemGenerator {

    /// Main-sequence mass–luminosity relation, valid from red dwarfs to O stars.
    /// (The original's single exponent goes negative above ~10 solar masses.)
    /// The slope flattens above 20 solar masses, matching O-star calibrations.
    func luminosity(_ massRatio: Double) -> Double {
        switch massRatio {
        case ..<0.43: 0.23 * pow(massRatio, 2.3)
        case ..<2.0: pow(massRatio, 4.0)
        case ..<20.0: 1.4 * pow(massRatio, 3.5)
        default: 1.4 * pow(20.0, 3.5) * pow(massRatio / 20.0, 2.5)
        }
    }

    /// Orbital 'zone' (1, 2 or 3) for an orbital radius in AU.
    func orbitalZone(_ orbitalRadius: Double) -> Int {
        let l = sqrt(stellarLuminosityRatio)
        if orbitalRadius < 4.0 * l { return 1 }
        if orbitalRadius < 15.0 * l { return 2 }
        return 3
    }

    /// Mass in solar masses, density in g/cc; returns radius in km.
    func volumeRadius(_ mass: Double, _ density: Double) -> Double {
        let volume = mass * Const.solarMassInGrams / density
        return pow((3.0 * volume) / (4.0 * Double.pi), 1.0 / 3.0) / Const.cmPerKM
    }

    /// Kothari's eq.23 (Fogg's eq.9). Returns radius in km.
    func kothariRadius(_ mass: Double, _ orbitalRadius: Double, _ giant: Bool, _ zone: Int) -> Double {
        let atomicWeight: Double
        let atomicNum: Double
        switch (zone, giant) {
        case (1, true):  atomicWeight = 9.5;  atomicNum = 4.5
        case (1, false): atomicWeight = 15.0; atomicNum = 8.0
        case (2, true):  atomicWeight = 2.47; atomicNum = 2.0
        case (2, false): atomicWeight = 10.0; atomicNum = 5.0
        case (_, true):  atomicWeight = 7.0;  atomicNum = 4.0
        case (_, false): atomicWeight = 10.0; atomicNum = 5.0
        }

        var temp = atomicWeight * atomicNum
        temp = (2.0 * Const.beta_20 * pow(Const.solarMassInGrams, 1.0 / 3.0))
            / (Const.a1_20 * pow(temp, 1.0 / 3.0))
        var temp2 = Const.a2_20 * pow(atomicWeight, 4.0 / 3.0) * pow(Const.solarMassInGrams, 2.0 / 3.0)
        temp2 *= pow(mass, 2.0 / 3.0)
        temp2 /= Const.a1_20 * pow(atomicNum, 2.0)
        temp2 = 1.0 + temp2
        temp /= temp2
        return (temp * pow(mass, 1.0 / 3.0)) / Const.cmPerKM
    }

    /// Mass in solar masses, orbit in AU; returns g/cc.
    func empiricalDensity(_ mass: Double, _ orbitalRadius: Double, _ gasGiant: Bool) -> Double {
        var temp = pow(mass * Const.earthMassesPerSolarMass, 1.0 / 8.0)
        temp *= pow(rEcosphere / orbitalRadius, 1.0 / 4.0)
        return gasGiant ? temp * 1.2 : temp * 5.5
    }

    /// Mass in solar masses, radius in km; returns g/cc.
    func volumeDensity(_ mass: Double, _ equatorialRadius: Double) -> Double {
        let m = mass * Const.solarMassInGrams
        let r = equatorialRadius * Const.cmPerKM
        let volume = (4.0 * Double.pi * pow(r, 3.0)) / 3.0
        return m / volume
    }

    /// Separation in AU, masses in solar masses; returns Earth days.
    func period(_ separation: Double, _ smallMass: Double, _ largeMass: Double) -> Double {
        sqrt(pow(separation, 3.0) / (smallMass + largeMass)) * Const.daysInAYear
    }

    /// Fogg's eq.12/13. Returns (hours per rotation, in spin resonance).
    func dayLength(_ mass: Double, _ radius: Double, _ orbitalPeriod: Double,
                   _ eccentricity: Double, _ giant: Bool) -> (Double, Bool) {
        var spinResonance = false
        let k2 = giant ? 0.24 : 0.33
        let massInGrams = mass * Const.solarMassInGrams
        let radiusInCm = radius * Const.cmPerKM
        let baseAngularVelocity = sqrt(2.0 * Const.j * massInGrams / (k2 * pow(radiusInCm, 2.0)))
        // Slowing by moons (dw/dt) is not modelled in the original.
        let changeInAngularVelocity = 0.0
        var temp = baseAngularVelocity + changeInAngularVelocity * age
        // rad/sec -> hours/rotation
        temp = 1.0 / ((temp / radiansPerRotation) * Const.secondsPerHour)
        if temp >= orbitalPeriod {
            let spinResonancePeriod = ((1.0 - eccentricity) / (1.0 + eccentricity)) * orbitalPeriod
            if eccentricity > 0.1 {
                temp = spinResonancePeriod
                spinResonance = true
            } else {
                temp = orbitalPeriod
            }
        }
        return (temp, spinResonance)
    }

    /// Axial tilt in degrees.
    func inclination(_ orbitalRadius: Double) -> Int {
        Int(pow(orbitalRadius, 0.2) * about(Const.earthAxialTilt, 0.4)) % 360
    }

    /// Mass in solar masses, radius in km; returns cm/sec.
    func escapeVel(_ mass: Double, _ radius: Double) -> Double {
        sqrt(2.0 * Const.gravConstant * mass * Const.solarMassInGrams / (radius * Const.cmPerKM))
    }

    /// Fogg's eq.16. Returns RMS velocity in cm/sec.
    /// The distance is scaled by the ecosphere so exosphere heating follows the star's
    /// luminosity (the original assumed a sun-like star).
    func rmsVel(_ molecularWeight: Double, _ orbitalRadius: Double) -> Double {
        let exosphericTemp = Const.earthExosphereTemp / pow(orbitalRadius / rEcosphere, 2.0)
        return sqrt((3.0 * Const.molarGasConst * exosphericTemp) / molecularWeight) * Const.cmPerMeter
    }

    /// Smallest molecular weight retained by the body.
    func moleculeLimit(_ orbitalRadius: Double, _ mass: Double, _ equatorialRadius: Double) -> Double {
        let v = escapeVel(mass, equatorialRadius)
        return (3.0 * pow(Const.gasRetentionThreshold * Const.cmPerMeter, 2.0)
                * Const.molarGasConst * Const.earthExosphereTemp) / pow(v, 2.0)
    }

    /// Mass in solar masses, radius in km; returns cm/sec2.
    func acceleration(_ mass: Double, _ radius: Double) -> Double {
        Const.gravConstant * (mass * Const.solarMassInGrams) / pow(radius * Const.cmPerKM, 2.0)
    }

    /// cm/sec2 -> Earth gravities.
    func gravity(_ acceleration: Double) -> Double {
        acceleration / Const.earthAcceleration
    }

    func greenhouse(_ zone: Int, _ orbitalRadius: Double, _ greenhouseRadius: Double) -> Bool {
        orbitalRadius < greenhouseRadius && zone == 1
    }

    /// Fogg's eq.17. Unitless.
    func volInventory(_ mass: Double, _ escapeVel: Double, _ rmsVel: Double, _ stellarMass: Double,
                      _ zone: Int, _ greenhouseEffect: Bool) -> Double {
        guard escapeVel / rmsVel >= Const.gasRetentionThreshold else { return 0.0 }
        let proportionConst: Double
        switch zone {
        case 1: proportionConst = 100_000.0
        case 2: proportionConst = 75_000.0
        case 3: proportionConst = 250.0
        default:
            print("Error: orbital zone not initialized correctly!")
            proportionConst = 0.0
        }
        let massInEarthUnits = mass * Const.earthMassesPerSolarMass
        let temp1 = (proportionConst * massInEarthUnits) / stellarMass
        let temp2 = about(temp1, 0.2)
        return greenhouseEffect ? temp2 : temp2 / 100.0
    }

    /// Fogg's eq.18. Returns millibars.
    func pressure(_ volatileGasInventory: Double, _ equatorialRadius: Double, _ gravity: Double) -> Double {
        let r = Const.earthRadiusInKM / equatorialRadius
        return volatileGasInventory * gravity / pow(r, 2.0)
    }

    /// Fogg's eq.21. Pressure in millibars; returns Kelvin.
    func boilingPoint(_ surfacePressure: Double) -> Double {
        let bars = surfacePressure / Const.millibarsPerBar
        return 1.0 / (log(bars) / -5050.5 + 1.0 / 373.0)
    }

    /// Fogg's eq.22 (71% Earth water coverage).
    func hydrosphereFraction(_ volatileGasInventory: Double, _ planetaryRadius: Double) -> Double {
        let temp = (0.71 * volatileGasInventory / 1000.0) * pow(Const.earthRadiusInKM / planetaryRadius, 2.0)
        return min(temp, 1.0)
    }

    /// Fogg's eq.23 / Hart's eq.3.
    func cloudFraction(_ surfaceTemp: Double, _ smallestMWRetained: Double,
                       _ equatorialRadius: Double, _ hydrosphereFraction: Double) -> Double {
        if smallestMWRetained > MolecularWeight.waterVapor { return 0.0 }
        let surfaceArea = 4.0 * Double.pi * pow(equatorialRadius, 2.0)
        let hydrosphereMass = hydrosphereFraction * surfaceArea * Const.earthWaterMassPerArea
        let waterVaporInKg = (0.00000001 * hydrosphereMass) * exp(Const.q2_36 * (surfaceTemp - 288.0))
        let fraction = Const.cloudCoverageFactor * waterVaporInKg / surfaceArea
        return min(fraction, 1.0)
    }

    /// Fogg's eq.24 (constant changed from 70 to 90).
    func iceFraction(_ hydrosphereFraction: Double, _ surfaceTemp: Double) -> Double {
        let t = min(surfaceTemp, 328.0)
        var temp = pow((328.0 - t) / 90.0, 5.0)
        if temp > 1.5 * hydrosphereFraction { temp = 1.5 * hydrosphereFraction }
        return min(temp, 1.0)
    }

    /// Fogg's eq.19. Returns Kelvin.
    func effTemp(_ ecosphereRadius: Double, _ orbitalRadius: Double, _ albedo: Double) -> Double {
        sqrt(ecosphereRadius / orbitalRadius) * pow((1.0 - albedo) / 0.7, 0.25) * Const.earthEffectiveTemp
    }

    /// Fogg's eq.20 / Hart's eq.20. Returns the greenhouse temperature rise (K).
    func greenRise(_ opticalDepth: Double, _ effectiveTemp: Double, _ surfacePressure: Double) -> Double {
        let convectionFactor = Const.earthConvectionFactor
            * pow(surfacePressure / Const.earthSurfPresInMillibars, 0.25)
        return (pow(1.0 + 0.75 * opticalDepth, 0.25) - 1.0) * effectiveTemp * convectionFactor
    }

    func planetAlbedo(_ waterFraction: Double, _ cloudFraction: Double,
                      _ iceFraction: Double, _ surfacePressure: Double) -> Double {
        var water = waterFraction
        var ice = iceFraction
        var rock = 1.0 - water - ice

        var components = 0.0
        if water > 0.0 { components += 1.0 }
        if ice > 0.0 { components += 1.0 }
        if rock > 0.0 { components += 1.0 }
        let cloudAdjustment = cloudFraction / components

        rock = rock >= cloudAdjustment ? rock - cloudAdjustment : 0.0
        water = water > cloudAdjustment ? water - cloudAdjustment : 0.0
        ice = ice > cloudAdjustment ? ice - cloudAdjustment : 0.0

        let airless = surfacePressure == 0.0
        let cloudContribution = cloudFraction * about(Const.cloudAlbedo, 0.2)
        let rockContribution = airless
            ? rock * about(Const.airlessRockyAlbedo, 0.3)
            : rock * about(Const.rockyAlbedo, 0.1)
        let waterContribution = water * about(Const.waterAlbedo, 0.2)
        let iceContribution = airless
            ? ice * about(Const.airlessIceAlbedo, 0.4)
            : ice * about(Const.iceAlbedo, 0.1)
        return cloudContribution + rockContribution + waterContribution + iceContribution
    }

    /// Dimensionless optical depth used for the greenhouse effect.
    func opacity(_ molecularWeight: Double, _ surfacePressure: Double) -> Double {
        var depth = 0.0
        switch molecularWeight {
        case 0.0..<10.0:   depth += 3.0
        case 10.0..<20.0:  depth += 2.34
        case 20.0..<30.0:  depth += 1.0
        case 30.0..<45.0:  depth += 0.15
        case 45.0..<100.0: depth += 0.05
        default: break
        }
        let p = Const.earthSurfPresInMillibars
        if surfacePressure >= 70.0 * p { depth *= 8.333 }
        else if surfacePressure >= 50.0 * p { depth *= 6.666 }
        else if surfacePressure >= 30.0 * p { depth *= 3.333 }
        else if surfacePressure >= 10.0 * p { depth *= 2.0 }
        else if surfacePressure >= 5.0 * p { depth *= 1.5 }
        return depth
    }

    /// Iterates albedo / greenhouse until the surface temperature settles (K).
    func iterateSurfaceTemp(_ planet: inout Planet) {
        var opticalDepth = opacity(planet.moleculeWeight, planet.surfacePressure)
        var effectiveTemp = effTemp(rEcosphere, planet.a, Const.earthAlbedo)
        var greenhouseRise = greenRise(opticalDepth, effectiveTemp, planet.surfacePressure)
        var surfaceTemp = effectiveTemp + greenhouseRise
        var previousTemp = surfaceTemp - 5.0    // force the loop the first time
        var albedo = 0.0, water = 0.0, clouds = 0.0, ice = 0.0
        var iterations = 0

        while abs(surfaceTemp - previousTemp) > 1.0 && iterations < 1000 {
            iterations += 1
            previousTemp = surfaceTemp
            water = hydrosphereFraction(planet.volatileGasInventory, planet.radius)
            clouds = cloudFraction(surfaceTemp, planet.moleculeWeight, planet.radius, water)
            ice = iceFraction(water, surfaceTemp)
            if surfaceTemp >= planet.boilPoint || surfaceTemp <= Const.freezingPointOfWater {
                water = 0.0
            }
            albedo = planetAlbedo(water, clouds, ice, planet.surfacePressure)
            opticalDepth = opacity(planet.moleculeWeight, planet.surfacePressure)
            effectiveTemp = effTemp(rEcosphere, planet.a, albedo)
            greenhouseRise = greenRise(opticalDepth, effectiveTemp, planet.surfacePressure)
            surfaceTemp = effectiveTemp + greenhouseRise
        }

        planet.hydrosphere = water
        planet.cloudCover = clouds
        planet.iceCover = ice
        planet.albedo = albedo
        planet.surfaceTemp = surfaceTemp
    }
}

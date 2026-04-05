//
//  SubsurfaceContactFilter.swift
//  Subsurface
//
//  Created by Kai Azim on 2026-04-05.
//

import CoreGraphics

/// Utility functions for filtering and analyzing multitouch contacts.
public enum SubsurfaceContactFilter {
    /// Removes palm contacts, keeping only identified finger touches.
    ///
    /// A contact is considered a palm if either ``MTContact/finger`` or ``MTContact/hand`` is `nil`.
    ///
    /// - Parameter contacts: The raw contacts to filter.
    /// - Returns: Contacts where both `finger` and `hand` are non-nil.
    public static func removePalms(from contacts: [MTContact]) -> [MTContact] {
        contacts.filter { $0.finger != nil && $0.hand != nil }
    }

    /// Returns contacts that are actively touching the trackpad surface.
    ///
    /// Filters to contacts in the ``MTContactState/touching`` or ``MTContactState/making`` state.
    ///
    /// - Parameter contacts: The raw contacts to filter.
    /// - Returns: Contacts with an active touch state.
    public static func activeTouches(from contacts: [MTContact]) -> [MTContact] {
        contacts.filter { $0.contactState == .touching || $0.contactState == .making }
    }

    /// Computes the centroid (average normalized position) of the given contacts.
    ///
    /// - Parameter contacts: The contacts to average.
    /// - Returns: The average position, or `.zero` if `contacts` is empty.
    public static func centroid(of contacts: [MTContact]) -> CGPoint {
        guard !contacts.isEmpty else { return .zero }

        let sum = contacts.reduce(into: CGPoint.zero) { result, contact in
            result.x += CGFloat(contact.normalizedVector.position.x)
            result.y += CGFloat(contact.normalizedVector.position.y)
        }

        return CGPoint(
            x: sum.x / CGFloat(contacts.count),
            y: sum.y / CGFloat(contacts.count)
        )
    }

    /// Computes the euclidean distance between exactly two contacts' normalized positions.
    ///
    /// - Parameter contacts: Exactly two contacts.
    /// - Returns: The distance between them, or `nil` if the count is not exactly 2.
    public static func interFingerDistance(between contacts: [MTContact]) -> CGFloat? {
        guard contacts.count == 2 else { return nil }

        let p1 = contacts[0].normalizedVector.position
        let p2 = contacts[1].normalizedVector.position

        return hypot(
            CGFloat(p2.x - p1.x),
            CGFloat(p2.y - p1.y)
        )
    }

    /// Computes the maximum pairwise distance between any two contacts' normalized positions.
    ///
    /// Supports any number of fingers (N >= 2).
    ///
    /// - Parameter contacts: The contacts to measure.
    /// - Returns: The largest distance between any pair, or `0` if fewer than 2 contacts.
    public static func maxInterFingerDistance(of contacts: [MTContact]) -> CGFloat {
        guard contacts.count >= 2 else { return 0 }

        var maxDistance: CGFloat = 0

        for i in 0 ..< contacts.count {
            for j in (i + 1) ..< contacts.count {
                let p1 = contacts[i].normalizedVector.position
                let p2 = contacts[j].normalizedVector.position
                let distance = hypot(
                    CGFloat(p2.x - p1.x),
                    CGFloat(p2.y - p1.y)
                )
                maxDistance = max(maxDistance, distance)
            }
        }

        return maxDistance
    }

    /// Returns the pair of contacts that are farthest apart.
    ///
    /// - Parameter contacts: The contacts to search.
    /// - Returns: The two farthest contacts, or `nil` if fewer than 2.
    static func farthestPair(of contacts: [MTContact]) -> (MTContact, MTContact)? {
        guard contacts.count >= 2 else { return nil }

        var maxDistance: CGFloat = 0
        var bestPair: (MTContact, MTContact)?

        for i in 0 ..< contacts.count {
            for j in (i + 1) ..< contacts.count {
                let p1 = contacts[i].normalizedVector.position
                let p2 = contacts[j].normalizedVector.position
                let distance = hypot(
                    CGFloat(p2.x - p1.x),
                    CGFloat(p2.y - p1.y)
                )
                if distance > maxDistance {
                    maxDistance = distance
                    bestPair = (contacts[i], contacts[j])
                }
            }
        }

        return bestPair
    }

    /// Computes the angle of the line between the two farthest-apart contacts.
    ///
    /// For N > 2 contacts, the two farthest apart are used as the reference pair.
    ///
    /// - Parameter contacts: The contacts to measure.
    /// - Returns: The angle in radians, or `nil` if fewer than 2 contacts.
    public static func interFingerAngle(of contacts: [MTContact]) -> CGFloat? {
        guard let (a, b) = farthestPair(of: contacts) else { return nil }

        let dx = CGFloat(b.normalizedVector.position.x - a.normalizedVector.position.x)
        let dy = CGFloat(b.normalizedVector.position.y - a.normalizedVector.position.y)

        return atan2(dy, dx)
    }
}
